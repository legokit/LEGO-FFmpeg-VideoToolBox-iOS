//
//  FFmpegViewController.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "FFmpegViewController.h"
#import "VPVideoStreamPlayLayer.h"
#import "FFmpegDecoderTool.h"

// FFmpeg Header File
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

@interface FFmpegViewController ()<FFmpegDecoderToolDelegate>
@property (nonatomic, strong) VPVideoStreamPlayLayer *previewView;


@end

@implementation FFmpegViewController

- (VPVideoStreamPlayLayer *)previewView
{
    if (!_previewView) {
        _previewView = [[VPVideoStreamPlayLayer alloc] initWithFrame:self.view.bounds];
    }
    return _previewView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.whiteColor;
    
    self.title = @"FFmpeg";

    [self.view.layer addSublayer:self.previewView];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"IMG_0767" ofType:@"MOV"];
        
    FFmpegDecoderTool *decoderTool = [[FFmpegDecoderTool alloc] initWithPath:path];
    CGSize size = [decoderTool getVideoSize];
    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width / size.width * size.height);
    self.previewView.frame = frame;
    decoderTool.delegate = self;
    [decoderTool startParseGetAVPackeWithCompletionHandler:^(BOOL isVideoFrame, BOOL isFinish, AVPacket packet) {
        if (isFinish) {
            [decoderTool stopDecoder];
            return;
        }
        if (isVideoFrame) {
            [decoderTool startDecodeVideoDataWithAVPacket:packet];
        }
    }];
    
    // Do any additional setup after loading the view.
}

-(void)getDecodeVideoDataByFFmpeg:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.previewView inputPixelBuffer:pix];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

@end

