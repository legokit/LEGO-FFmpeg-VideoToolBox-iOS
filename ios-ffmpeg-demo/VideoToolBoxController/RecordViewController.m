//
//  RecordViewController.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "RecordViewController.h"

@interface RecordViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    int frameNO;//帧号
    //录制队列
    dispatch_queue_t captureQueue;
}

@property (nonatomic,strong)AVCaptureSession *captureSession; //输入和输出数据传输session
@property (nonatomic,strong)AVCaptureDeviceInput *captureDeviceInput; //从AVdevice获得输入数据
@property (nonatomic,strong)AVCaptureVideoDataOutput *captureDeviceOutput; //获取输出数据
@property (nonatomic,strong)AVCaptureVideoPreviewLayer *previewLayer; //预览layer
@property (nonatomic,strong)UIButton *startBtn;

@end

@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    [self.view addSubview:self.startBtn];
    
    captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);


    // Do any additional setup after loading the view.
}

- (void)startBtnAction{
    BOOL isRunning = self.captureSession && self.captureSession.running;
    
    if (isRunning) {
        //停止采集编码
        [self.startBtn setTitle:@"Start" forState:UIControlStateNormal];
        [self endCaputureSession];
    }
    else{
        //开始采集编码
        [self.startBtn setTitle:@"End" forState:UIControlStateNormal];
        [self startCaputureSession];
    }
}

- (void)startCaputureSession {
    [self initCapture];
    [self initPreviewLayer];
    //开始采集
    [self.captureSession startRunning];
}


- (void)endCaputureSession {
    //停止采集
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

}

- (void)initCapture {
    
    self.captureSession = [[AVCaptureSession alloc]init];
    
    //设置录制 4k
    self.captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
    
    AVCaptureDevice *inputCamera = [self cameraWithPostion:AVCaptureDevicePositionBack];
  
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    
    if ([self.captureSession canAddInput:self.captureDeviceInput]) {
        [self.captureSession addInput:self.captureDeviceInput];
    }
    
    self.captureDeviceOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.captureDeviceOutput setAlwaysDiscardsLateVideoFrames:NO];
    
    //设置YUV420p输出
    [self.captureDeviceOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [self.captureDeviceOutput setSampleBufferDelegate:self queue:captureQueue];
    
    if ([self.captureSession canAddOutput:self.captureDeviceOutput]) {
        [self.captureSession addOutput:self.captureDeviceOutput];
    }
    
    //建立连接
    AVCaptureConnection *connection = [self.captureDeviceOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
}


//config 摄像头预览layer
- (void)initPreviewLayer {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.previewLayer setFrame:self.view.bounds];
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
}

//兼容iOS10以上获取AVCaptureDevice
- (AVCaptureDevice *)cameraWithPostion:(AVCaptureDevicePosition)position{
    if (@available(iOS 10.0, *)) {
        // iOS10以上
        AVCaptureDeviceDiscoverySession *devicesIOS10 = [AVCaptureDeviceDiscoverySession  discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
        NSArray *devicesIOS  = devicesIOS10.devices;
        for (AVCaptureDevice *device in devicesIOS) {
            if ([device position] == position) {
                return device;
            }
        }
        return nil;
    } else {
        // iOS10以下
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices)
        {
            if ([device position] == position)
            {
                return device;
            }
        }
        return nil;
    }
}

- (UIButton *)startBtn{
    if (!_startBtn) {
        _startBtn = [[UIButton alloc]initWithFrame:CGRectMake(220, 30, 100, 50)];
        [_startBtn setBackgroundColor:[UIColor cyanColor]];
        [_startBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_startBtn setTitle:@"start" forState:UIControlStateNormal];
        [_startBtn addTarget:self action:@selector(startBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _startBtn;
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
