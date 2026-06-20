#import "ProductionEmbeddedQVACBareHostBridge.h"
#import <BareKit/BareKit.h>

static NSString *const ProductionEmbeddedQVACBareHostBridgeErrorDomain = @"ProductionEmbeddedQVACBareHostBridge";
static NSString *ProductionEmbeddedQVACBareHostStatusResponderSource(void);
static NSString *ProductionEmbeddedQVACBareHostAnswerResponderSource(void);

// Answer-request timeout. Model load + first-run download (~770MB) + generation
// can take well over a minute; matches the Swift-side responder timeout.
static const int64_t ProductionEmbeddedQVACBareHostAnswerTimeoutSeconds = 600;

@interface ProductionEmbeddedQVACBareHostStatusRequest : NSObject

- (instancetype)initWithRequestData:(NSData *)requestData
                          completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;
- (void)start;

@end

// Owns the ONE long-lived answer worklet for the whole app. See the big comment
// on the implementation for why this must not be recreated per request.
@interface ProductionEmbeddedQVACBareHostAnswerWorkletHost : NSObject

+ (instancetype)shared;
- (void)enqueueRequest:(NSData *)requestData
            completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;

@end

@implementation ProductionEmbeddedQVACBareHostBridge

+ (void)sendStatusRequest:(NSData *)requestData
               completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion
{
  dispatch_async(dispatch_get_main_queue(), ^{
    ProductionEmbeddedQVACBareHostStatusRequest *request =
      [[ProductionEmbeddedQVACBareHostStatusRequest alloc] initWithRequestData:requestData
                                                                    completion:completion];
    [request start];
  });
}

+ (void)sendAnswerRequest:(NSData *)requestData
               completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion
{
  // Route every answer to the single persistent worklet rather than spinning up
  // a fresh BareWorklet per request (which crashed the app — see the host).
  [[ProductionEmbeddedQVACBareHostAnswerWorkletHost shared] enqueueRequest:requestData
                                                               completion:completion];
}

@end

@interface ProductionEmbeddedQVACBareHostStatusRequest ()

@property(nonatomic, strong) NSData *requestData;
@property(nonatomic, copy) void (^completion)(NSData *_Nullable data, NSError *_Nullable error);
@property(nonatomic, strong, nullable) BareWorklet *worklet;
@property(nonatomic, strong, nullable) ProductionEmbeddedQVACBareHostStatusRequest *retainedSelf;
@property(nonatomic, assign) BOOL completed;

@end

@implementation ProductionEmbeddedQVACBareHostStatusRequest

- (instancetype)initWithRequestData:(NSData *)requestData
                          completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion
{
  self = [super init];
  if (self) {
    _requestData = requestData;
    _completion = [completion copy];
  }

  return self;
}

- (void)start
{
  self.retainedSelf = self;

  self.worklet = [[BareWorklet alloc] initWithConfiguration:nil];

  if (self.worklet == nil) {
    [self finishWithData:nil
                   error:[NSError errorWithDomain:ProductionEmbeddedQVACBareHostBridgeErrorDomain
                                             code:1
                                         userInfo:nil]];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [self.worklet start:@"/embedded-qvac-host/status-responder.js"
               source:ProductionEmbeddedQVACBareHostStatusResponderSource()
             encoding:NSUTF8StringEncoding
            arguments:nil];

  [self.worklet push:self.requestData
               queue:[NSOperationQueue mainQueue]
          completion:^(NSData *_Nullable data, NSError *_Nullable error) {
            [weakSelf finishWithData:data error:error];
          }];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!weakSelf.completed) {
      [weakSelf finishWithData:nil
                         error:[NSError errorWithDomain:ProductionEmbeddedQVACBareHostBridgeErrorDomain
                                                   code:3
                                               userInfo:nil]];
    }
  });
}

- (void)finishWithData:(NSData *_Nullable)data error:(NSError *_Nullable)error
{
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self finishWithData:data error:error];
    });
    return;
  }

  if (self.completed) {
    return;
  }

  self.completed = YES;
  BareWorklet *worklet = self.worklet;
  void (^completion)(NSData *_Nullable, NSError *_Nullable) = self.completion;
  self.completion = nil;
  self.worklet = nil;
  self.retainedSelf = nil;

  [worklet terminate];

  if (completion != nil) {
    completion(data, error);
  }
}

@end

// MARK: - Answer worklet host (persistent, single instance)

// WHY THIS IS A SINGLETON, NOT A PER-REQUEST OBJECT:
//
// The answer worklet loads the full @qvac/sdk bundle, whose native addons
// (e.g. qvac__bci-whispercpp's JsLogger) keep static js_ref handles into the
// worklet's V8 isolate and persist across worklet instances in the app
// process. Recreating a BareWorklet per request re-ran initializeWorkerCore()
// in a NEW isolate; the shared addon's setLogger then called releaseJsRefs on
// the PREVIOUS (already-destroyed) isolate's ref → EXC_BAD_ACCESS that took
// down the whole app on the 2nd+ question. (worker-core.js documents this and
// expects cleanupForTerminate() before any teardown.) Recreating per request
// also threw away the worklet's cached model, forcing a ~770MB reload every
// time (slow, and the memory churn behind the OOM jetsam).
//
// Keeping ONE worklet alive for the app's lifetime removes the re-init
// entirely, keeps the model resident, and never tears the isolate down.
//
// All state (worklet, queue, busy) is touched ONLY on the main queue, so the
// FIFO needs no locks. The worklet processes one push at a time (its JS side
// holds a single pending reply), so requests are serialized: the next push
// starts only when the previous push's real reply arrives. A per-request
// timeout fails the caller early but deliberately does NOT advance the queue
// or terminate the worklet — advancing into a still-busy single-isolate
// worklet would corrupt it, and terminating would reintroduce the recreation
// crash. The queue advances solely on the genuine BareKit reply.
@interface ProductionEmbeddedQVACBareHostAnswerWorkletHost ()

@property(nonatomic, strong, nullable) BareWorklet *worklet;
@property(nonatomic, assign) BOOL workletStarted;
@property(nonatomic, assign) BOOL busy;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *pending;

@end

@implementation ProductionEmbeddedQVACBareHostAnswerWorkletHost

+ (instancetype)shared
{
  static ProductionEmbeddedQVACBareHostAnswerWorkletHost *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[ProductionEmbeddedQVACBareHostAnswerWorkletHost alloc] init];
  });
  return instance;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _pending = [NSMutableArray array];
  }
  return self;
}

- (void)enqueueRequest:(NSData *)requestData
            completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion
{
  void (^copiedCompletion)(NSData *_Nullable, NSError *_Nullable) = [completion copy];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.pending addObject:@{ @"data" : requestData,
                               @"completion" : (copiedCompletion ?: ^(NSData *d, NSError *e){}) }];
    [self pumpQueue];
  });
}

// Main queue only.
- (void)pumpQueue
{
  if (self.busy || self.pending.count == 0) {
    return;
  }

  if (![self ensureWorkletStarted]) {
    NSDictionary *job = self.pending.firstObject;
    [self.pending removeObjectAtIndex:0];
    void (^completion)(NSData *_Nullable, NSError *_Nullable) = job[@"completion"];
    completion(nil, [NSError errorWithDomain:ProductionEmbeddedQVACBareHostBridgeErrorDomain
                                        code:1
                                    userInfo:nil]);
    [self pumpQueue];
    return;
  }

  self.busy = YES;
  NSDictionary *job = self.pending.firstObject;
  [self.pending removeObjectAtIndex:0];
  NSData *requestData = job[@"data"];
  void (^completion)(NSData *_Nullable, NSError *_Nullable) = job[@"completion"];

  __weak typeof(self) weakSelf = self;
  __block BOOL settled = NO;

  [self.worklet push:requestData
               queue:[NSOperationQueue mainQueue]
          completion:^(NSData *_Nullable data, NSError *_Nullable error) {
            // The genuine reply: deliver to the caller if it hasn't already
            // timed out, then ALWAYS free the worklet and run the next request.
            if (!settled) {
              settled = YES;
              completion(data, error);
            }
            weakSelf.busy = NO;
            [weakSelf pumpQueue];
          }];

  // Safety net only: fail the caller, but leave `busy` set so we never push
  // into the still-generating worklet. The queue advances when the real reply
  // above arrives.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(ProductionEmbeddedQVACBareHostAnswerTimeoutSeconds * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (!settled) {
      settled = YES;
      completion(nil, [NSError errorWithDomain:ProductionEmbeddedQVACBareHostBridgeErrorDomain
                                          code:3
                                      userInfo:nil]);
    }
  });
}

// Main queue only. Creates + starts the worklet exactly once.
- (BOOL)ensureWorkletStarted
{
  if (self.workletStarted && self.worklet != nil) {
    return YES;
  }

  BareWorklet *worklet = [[BareWorklet alloc] initWithConfiguration:nil];
  if (worklet == nil) {
    return NO;
  }

  // Load the real bare-packed worklet, falling back to the inline error
  // responder if its resource is missing.
  NSString *bundleSource = nil;
  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"answer-worker.bundle" ofType:@"js"];
  if (bundlePath != nil) {
    bundleSource = [NSString stringWithContentsOfFile:bundlePath
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
  }

  // The name must end in ".bundle" so BareKit parses the bare-pack format; a
  // ".js" name makes it eval the bundle as plain JS and choke on its JSON header.
  NSString *workletName = bundleSource != nil ? @"/answer-worker.bundle" : @"/embedded-qvac-host/answer-responder.js";
  NSString *workletSource = bundleSource != nil ? bundleSource : ProductionEmbeddedQVACBareHostAnswerResponderSource();

  [worklet start:workletName
          source:workletSource
        encoding:NSUTF8StringEncoding
       arguments:nil];

  self.worklet = worklet;
  self.workletStarted = YES;
  return YES;
}

@end

// MARK: - Status responder source

static NSString *ProductionEmbeddedQVACBareHostStatusResponderSource(void)
{
  return @"const protocol = 'qvac.embeddedHost.status.v1'\n"
  "\n"
  "function unavailableResponse(requestID) {\n"
  "  return {\n"
  "    protocol,\n"
  "    type: 'qvac.host.status.response',\n"
  "    requestID,\n"
  "    status: 'unavailable',\n"
  "    diagnostic: 'embedded-qvac-host-unavailable'\n"
  "  }\n"
  "}\n"
  "\n"
  "BareKit.on('push', (data, reply) => {\n"
  "  let requestID = null\n"
  "\n"
  "  try {\n"
  "    const request = JSON.parse(data.toString())\n"
  "    requestID = typeof request.requestID === 'string' ? request.requestID : null\n"
  "\n"
  "    if (request.protocol !== protocol || request.type !== 'qvac.host.status') {\n"
  "      reply(null, Buffer.from(JSON.stringify(unavailableResponse(requestID))))\n"
  "      return\n"
  "    }\n"
  "\n"
  "    reply(null, Buffer.from(JSON.stringify({\n"
  "      protocol,\n"
  "      type: 'qvac.host.status.response',\n"
  "      requestID,\n"
  "      status: 'ready',\n"
  "      diagnostic: 'embedded-qvac-host-ready',\n"
  "      runtime: 'bare'\n"
  "    })))\n"
  "  } catch {\n"
  "    reply(null, Buffer.from(JSON.stringify(unavailableResponse(requestID))))\n"
  "  }\n"
  "})\n";
}

// Minimal fallback that just reports an error. Real generation runs in the
// bare-packed answer-worker.bundle; this is only used if that resource is missing.
static NSString *ProductionEmbeddedQVACBareHostAnswerResponderSource(void)
{
  return @"const protocol = 'qvac.embeddedHost.answer.v1'\n"
  "\n"
  "function errorResponse(requestID, errorCode, errorMessage) {\n"
  "  return {\n"
  "    protocol,\n"
  "    type: 'qvac.host.answer.response',\n"
  "    requestID,\n"
  "    status: 'error',\n"
  "    errorCode,\n"
  "    errorMessage\n"
  "  }\n"
  "}\n"
  "\n"
  "BareKit.on('push', (data, reply) => {\n"
  "  let requestID = null\n"
  "\n"
  "  try {\n"
  "    const request = JSON.parse(data.toString())\n"
  "    requestID = typeof request.requestID === 'string' ? request.requestID : null\n"
  "\n"
  "    if (request.protocol !== protocol || request.type !== 'qvac.host.answer') {\n"
  "      reply(null, Buffer.from(JSON.stringify(errorResponse(requestID, 'invalid-protocol', 'Invalid protocol or type in answer request.'))))\n"
  "      return\n"
  "    }\n"
  "\n"
  "    // Inline fallback: real generation requires the bundled answer-responder.js.\n"
  "    reply(null, Buffer.from(JSON.stringify(errorResponse(requestID, 'bundled-responder-unavailable', 'The bundled answer-responder.js could not be loaded. On-device generation requires the full QVAC SDK worker.'))))\n"
  "  } catch {\n"
  "    reply(null, Buffer.from(JSON.stringify(errorResponse(requestID, 'answer-responder-error', 'Unexpected error in inline answer responder fallback.'))))\n"
  "  }\n"
  "})\n";
}
