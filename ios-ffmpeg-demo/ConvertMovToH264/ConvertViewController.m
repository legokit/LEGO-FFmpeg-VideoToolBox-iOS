//
//  ConvertViewController.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "ConvertViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SKVideoEncoder.h"

@interface ConvertViewController ()

@property (nonatomic, strong) AVAsset * asset;

@property (nonatomic, strong) AVAssetReader * assetReader;

@property (nonatomic, strong) AVAssetReaderOutput * videoOutput;

@property (nonatomic, strong) SKVideoEncoder * encoder;

@end

@implementation ConvertViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    // 配置 MP4 文件
     _asset = [self loadAsset: @"IMG_0767.MOV"];
     
     // 配置 Asset Reader
     AVAssetTrack *videoTrack = [_asset tracksWithMediaType: AVMediaTypeVideo].firstObject;
     _assetReader = [self createAssetReader: _asset];
     _videoOutput = [self setupAssetReaderOutput: videoTrack];

     
     NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"IMG_076712312313"];
    
//    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:H264FilePath];//

    
     // 注意，此处的宽高是 naturalSize，因为旋转了 90°，硬写会缺失数据。
     // 使用 naturalSize **编码后的数据也是** 旋转过的。
     _encoder = [[SKVideoEncoder alloc] initWithOptions:(SKVideoEncoderOptions) {
         .width = videoTrack.naturalSize.width,
         .height = videoTrack.naturalSize.height,
         .outputPath = file,
     }];
     
    
     // Asset Reader 开始读取
     [self startAssetReading];
     
     // 从 Asset Reader 中读取 （直到读到的 SampleBuffer 为 NULL）
     while (1) {
         CMSampleBufferRef sampleBuffer = [_videoOutput copyNextSampleBuffer];
         
         if (sampleBuffer == NULL) { // 读取完毕
             [self stopAssetReading];
             NSLog(@"Finish reading from asset");
             break;
         }
         
         // 编码
         [_encoder encode: sampleBuffer];
     }
     
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:file];//
                   UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:filePath]] applicationActivities:nil];
                   [self presentViewController:activityVC animated:YES completion:nil];
    });
    
     NSLog(@"Encode MP4 Finished, file path: %@", file);
    
    return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    
         // 注意，此处的宽高是 naturalSize，因为旋转了 90°，硬写会缺失数据。
         // 使用 naturalSize **编码后的数据也是** 旋转过的。
         _encoder = [[SKVideoEncoder alloc] initWithOptions:(SKVideoEncoderOptions) {
             .width = videoTrack.naturalSize.width,
             .height = videoTrack.naturalSize.height,
             .outputPath = file,
         }];
         
        
         // Asset Reader 开始读取
         [self startAssetReading];
         
         // 从 Asset Reader 中读取 （直到读到的 SampleBuffer 为 NULL）
         while (1) {
             CMSampleBufferRef sampleBuffer = [_videoOutput copyNextSampleBuffer];
             
             if (sampleBuffer == NULL) { // 读取完毕
                 [self stopAssetReading];
                 NSLog(@"Finish reading from asset");
                 break;
             }
             
             // 编码
             [_encoder encode: sampleBuffer];
         }
         
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:file];//
                       UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:filePath]] applicationActivities:nil];
                       [self presentViewController:activityVC animated:YES completion:nil];
        });
        
         NSLog(@"Encode MP4 Finished, file path: %@", file);
        
    });

    
    // Do any additional setup after loading the view.
}

#pragma mark - Load asset

- (AVAsset *)loadAsset: (NSString *)fileName {
    NSURL *mp4Url = [[NSBundle mainBundle] URLForResource: fileName withExtension: nil];
    return [AVAsset assetWithURL: mp4Url];
}

#pragma mark - Asset Reader

- (AVAssetReader *)createAssetReader: (AVAsset *)asset {
    NSError *err;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset: asset error: &err];
    
    NSAssert(assetReader != nil, @"error: %@", err);
    
    return assetReader;
}

- (AVAssetReaderTrackOutput *)setupAssetReaderOutput: (AVAssetTrack *)track {
    NSLog(@"size: %@", NSStringFromCGSize(track.naturalSize));
    NSDictionary *outputSettings = @{(id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
//                                     (id)kCVPixelBufferWidthKey : @(track.naturalSize.height),
//                                     (id)kCVPixelBufferHeightKey : @(track.naturalSize.width),
    };
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput
                                             assetReaderTrackOutputWithTrack: track
                                             outputSettings: outputSettings];
    
    if ([_assetReader canAddOutput: output]) {
        [_assetReader addOutput: output];
    } else {
        NSLog(@"Can't add output");
    }
    
    return output;
}

- (void)startAssetReading {
    if (![_assetReader startReading]) {
        NSLog(@"Can't start reading asset");
    }
}

- (void)stopAssetReading {
    [_assetReader cancelReading];
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end


