//
//  RecordViewController.h
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordViewController : UIViewController

- (void)startCaputureSession;
- (void)endCaputureSession;

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end

NS_ASSUME_NONNULL_END
