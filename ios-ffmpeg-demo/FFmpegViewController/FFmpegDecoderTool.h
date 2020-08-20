//
//  LEGOFFmpegTool.h
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
    
#ifdef __cplusplus
};
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol FFmpegDecoderToolDelegate <NSObject>

@optional

- (void)getDecodeVideoDataByFFmpeg:(CMSampleBufferRef)sampleBuffer;

@end

@interface FFmpegDecoderTool : NSObject

- (instancetype)initWithPath:(NSString *)path;

@property (nonatomic, weak) id <FFmpegDecoderToolDelegate> delegate;
 
- (CGSize)getVideoSize;

- (void)startParseGetAVPackeWithCompletionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handler;

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet;

- (void)stopDecoder;

@end

NS_ASSUME_NONNULL_END
