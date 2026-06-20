#import "ProductionEmbeddedQVACBareHostBridge.h"
#import <BareKit/BareKit.h>

static NSString *const ProductionEmbeddedQVACBareHostBridgeErrorDomain = @"ProductionEmbeddedQVACBareHostBridge";
static NSString *ProductionEmbeddedQVACBareHostStatusResponderSource(void);
static NSString *ProductionEmbeddedQVACBareHostAnswerResponderSource(void);

@interface ProductionEmbeddedQVACBareHostStatusRequest : NSObject

- (instancetype)initWithRequestData:(NSData *)requestData
                          completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;
- (void)start;

@end

@interface ProductionEmbeddedQVACBareHostAnswerRequest : NSObject

- (instancetype)initWithRequestData:(NSData *)requestData
                          completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;
- (void)start;

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
  dispatch_async(dispatch_get_main_queue(), ^{
    ProductionEmbeddedQVACBareHostAnswerRequest *request =
      [[ProductionEmbeddedQVACBareHostAnswerRequest alloc] initWithRequestData:requestData
                                                                    completion:completion];
    [request start];
  });
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

// MARK: - Answer request

@interface ProductionEmbeddedQVACBareHostAnswerRequest ()

@property(nonatomic, strong) NSData *requestData;
@property(nonatomic, copy) void (^completion)(NSData *_Nullable data, NSError *_Nullable error);
@property(nonatomic, strong, nullable) BareWorklet *worklet;
@property(nonatomic, strong, nullable) ProductionEmbeddedQVACBareHostAnswerRequest *retainedSelf;
@property(nonatomic, assign) BOOL completed;

@end

@implementation ProductionEmbeddedQVACBareHostAnswerRequest

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

  // Load the real bare-packed worklet, falling back to the inline error responder
  // if its resource is missing.
  NSString *bundleSource = nil;
  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"answer-worker.bundle" ofType:@"js"];
  if (bundlePath != nil) {
    bundleSource = [NSString stringWithContentsOfFile:bundlePath
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
  }

  // The name must end in ".bundle" so BareKit parses the bare-pack format; a ".js"
  // name makes it eval the bundle as plain JS and choke on its JSON header.
  NSString *workletName = bundleSource != nil ? @"/answer-worker.bundle" : @"/embedded-qvac-host/answer-responder.js";
  NSString *workletSource = bundleSource != nil ? bundleSource : ProductionEmbeddedQVACBareHostAnswerResponderSource();

  [self.worklet start:workletName
               source:workletSource
             encoding:NSUTF8StringEncoding
            arguments:nil];

  [self.worklet push:self.requestData
               queue:[NSOperationQueue mainQueue]
          completion:^(NSData *_Nullable data, NSError *_Nullable error) {
            [weakSelf finishWithData:data error:error];
          }];

  // First-run model download (~770MB) + load + generation is slow: 600s timeout.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(600 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
