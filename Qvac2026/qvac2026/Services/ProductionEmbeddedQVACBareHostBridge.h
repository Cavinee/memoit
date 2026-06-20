#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProductionEmbeddedQVACBareHostBridge : NSObject

+ (void)sendStatusRequest:(NSData *)requestData
               completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;

/// Sends an answer request to /embedded-qvac-host/answer-responder.js via BareKit.
/// Uses a 120-second timeout to accommodate model loading and generation time.
+ (void)sendAnswerRequest:(NSData *)requestData
               completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
