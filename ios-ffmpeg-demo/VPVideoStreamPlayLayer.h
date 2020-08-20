//
//  FFmpegViewController.h
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>

@interface VPVideoStreamPlayLayer : CAEAGLLayer

- (id)initWithFrame:(CGRect)frame;

- (void)inputPixelBuffer:(CVPixelBufferRef)pixelBuffer;


@end
