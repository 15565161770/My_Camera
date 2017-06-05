//
//  ViewController.m
//  自定义相机
//
//  Created by Xuan on 16/5/18.
//  Copyright © 2016年 Xuan. All rights reserved.
//
#define ratio         [[UIScreen mainScreen] bounds].size.width/320.0
#define kBgImgX             45*ratio
#define kBgImgY             (64+60)*ratio
#define kBgImgWidth         230*ratio

#define kScrollLineHeight   20*ratio

#define kTipY               (kBgImgY+kBgImgWidth+kTipHeight)
#define kTipHeight          40*ratio

#define kLampX              ([[UIScreen mainScreen] bounds].size.width-kLampWidth)/2
#define kLampY              ([[UIScreen mainScreen] bounds].size.height-kLampWidth-30*ratio)
#define kLampWidth          64*ratio

#define kBgAlpha            0.6
//获取当前设备的尺寸
#define ScreenWidth   [[UIScreen mainScreen] bounds].size.width
#define ScreenHeight  [[UIScreen mainScreen] bounds].size.height
#define ScreenSize    [[UIScreen mainScreen] bounds].size

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <QuartzCore/CALayer.h>
#import <dispatch/dispatch.h>
@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate>

/**
 *实际有效扫描区域的背景图(亦或者自己设置一个边框)
 */
@property (strong, nonatomic) UIImageView *bgImg;
@property (strong, nonatomic) AVCaptureSession *session;
//AVCaptureSession对象来执行输入设备和输出设备之间的数据传递

@property (nonatomic, strong)       AVCaptureDeviceInput        * videoInput;
//AVCaptureDeviceInput对象是输入流

@property (nonatomic, strong)       AVCaptureStillImageOutput   * stillImageOutput;
//照片输出流对象，当然我的照相机只有拍照功能，所以只需要这个对象就够了

@property (nonatomic, strong)       AVCaptureVideoPreviewLayer  * previewLayer;
//预览图层，来显示照相机拍摄到的画面
@property (nonatomic, strong)       UIBarButtonItem             * toggleButton;
//切换前后镜头的按钮
@property (nonatomic, strong)       UIButton                    * shutterButton;
//拍照按钮
@property (nonatomic, strong)       UIView                      * cameraShowView;
//放置预览图层的View
@property (nonatomic, strong) UIImageView *image ;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //1.添加一个可见的扫描有效区域的框（这里直接是设置一个背景图片）
    [self.view addSubview:self.bgImg];
    [self session];
    [self.view addSubview:self.shutterButton];
    [self.view addSubview:self.image];
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.session startRunning];
    
}
-(UIImageView *)image{
    if (!_image) {
        _image = [[UIImageView alloc]initWithFrame:CGRectMake(100, 100, 200, 200)];
    }
    return _image;
}
-(UIButton *)shutterButton{
    if (!_shutterButton) {
        _shutterButton = [[UIButton alloc]initWithFrame:CGRectMake(150, 550, 60, 60)];
        [_shutterButton setBackgroundColor:[UIColor yellowColor]];
        [_shutterButton setTitle:@"拍照" forState:UIControlStateNormal];
        [_shutterButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_shutterButton addTarget:self action:@selector(shutterCamera) forControlEvents:UIControlEventTouchUpInside];
    }
    return _shutterButton;
}
- (UIImageView *)bgImg {
    if (!_bgImg) {
        _bgImg = [[UIImageView alloc]initWithFrame:CGRectMake(kBgImgX, kBgImgY, kBgImgWidth, kBgImgWidth)];
        _bgImg.image = [UIImage imageNamed:@"scanBackground"];
    }
    return _bgImg;
}
- (AVCaptureSession *)session {
    if (!_session) {
        //1.获取输入设备（摄像头）
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        //2.根据输入设备创建输入对象
        self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        if (self.videoInput == nil) {
            return nil;
        }
        //3.创建输出对象
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        //这是输出流的设置参数AVVideoCodecJPEG参数表示以JPEG的图片格式输出图片
        NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [self.stillImageOutput setOutputSettings:outputSettings];
        // 4.创建会话(桥梁)
        AVCaptureSession *session = [[AVCaptureSession alloc]init];
        //实现高质量的输出和摄像，默认值为AVCaptureSessionPresetHigh，可以不写
        [session setSessionPreset:AVCaptureSessionPresetHigh];
        // 5.添加输入和输出到会话中（判断session是否已满）
        if ([session canAddInput:self.videoInput]) {
            [session addInput:self.videoInput];
        }
        if ([session canAddOutput:self.stillImageOutput]) {
            [session addOutput:self.stillImageOutput];
        }
        
        // 7.告诉输出对象, 需要输出什么样的数据 (二维码还是条形码等) 要先创建会话才能设置
//        output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypePDF417Code,AVMetadataObjectTypeAztecCode];
        
        // 8.创建预览图层
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        self.previewLayer.frame = self.view.bounds;
        [self.view.layer insertSublayer:self.previewLayer atIndex:0];
        
//        //9.设置有效扫描区域，默认整个图层(很特别，1、要除以屏幕宽高比例，2、其中x和y、width和height分别互换位置)
//        CGRect rect = CGRectMake(kBgImgY/ScreenHeight, kBgImgX/ScreenWidth, kBgImgWidth/ScreenHeight, kBgImgWidth/ScreenWidth);
//        self.stillImageOutput.rectOfInterest = rect;
        //10.设置中空区域，即有效扫描区域(中间扫描区域透明度比周边要低的效果)
        UIView *maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:kBgAlpha];
        [self.view addSubview:maskView];
        UIBezierPath *rectPath = [UIBezierPath bezierPathWithRect:self.view.bounds];
        [rectPath appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(45*ratio, (64+60)*ratio, 230*ratio, 230*ratio) cornerRadius:1] bezierPathByReversingPath]];
        CAShapeLayer *shapeLayer = [CAShapeLayer layer];
        shapeLayer.path = rectPath.CGPath;
        maskView.layer.mask = shapeLayer;
        
        _session = session;
    }
    return _session;
}
- (void) shutterCamera
{
    AVCaptureConnection * videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!videoConnection) {
        NSLog(@"take photo failed!");
        return;
    }
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage * imagevv = [UIImage imageWithData:imageData];
//        NSLog(@"image size = %@",NSStringFromCGSize(imagevv.size));
        UIImage *im =[self getSubImage:imagevv mCGRect:CGRectMake(kBgImgX, kBgImgY, kBgImgWidth, kBgImgWidth) centerBool:NO];
        self.image.image = im;
    }];
}

-(UIImage*)getSubImage:(UIImage *)image mCGRect:(CGRect)mCGRect centerBool:(BOOL)centerBool
{
    
    /*如若centerBool为Yes则是由中心点取mCGRect范围的图片*/
    
    
//    float imgwidth = image.size.width;
//    float imgheight = image.size.height;
//    float viewwidth = mCGRect.size.width;
//    float viewheight = mCGRect.size.height;
//    NSLog(@"%f--%f--%f--%f",imgwidth,imgheight,viewwidth,viewheight);
//    CGRect rect;
//    float ratiox = imgwidth/ScreenWidth;
//    float ratioy = imgheight/ScreenHeight;
//    rect = CGRectMake(mCGRect.origin.x, mCGRect.origin.y, mCGRect.size.width, mCGRect.size.height);
//    if(centerBool)
//        rect = CGRectMake((imgwidth-viewwidth)/2, (imgheight-viewheight)/2, viewwidth, viewheight);
//    else{
//        if (viewheight < viewwidth) {
//            if (imgwidth <= imgheight) {
//                rect = CGRectMake(0, 0, imgwidth, imgwidth*viewheight/viewwidth);
//            }else {
//                float width = viewwidth*imgheight/viewheight;
//                float x = (imgwidth - width)/2 ;
//                if (x > 0) {
//                    rect = CGRectMake(x, 0, width, imgheight);
//                }else {
//                    rect = CGRectMake(0, 0, imgwidth, imgwidth*viewheight/viewwidth);
//                }
//            }
//        }else {
//            if (imgwidth <= imgheight) {
//                float height = viewheight*imgwidth/viewwidth;
//                if (height < imgheight) {
//                    rect = CGRectMake(0, 0, imgwidth, height);
//                }else {
//                    rect = CGRectMake(0, 0, viewwidth*imgheight/viewheight, imgheight);
//                }
//            }else {
//                float width = viewwidth*imgheight/viewheight;
//                if (width < imgwidth) {
//                    float x = (imgwidth - width)/2 ;
//                    rect = CGRectMake(x, 0, width, imgheight);
//                }else {
//                    rect = CGRectMake(0, 0, imgwidth, imgheight);
//                }
//            }
//        }
//    }
    NSLog(@"%f,%f",image.size.height,image.size.width);
    float ratioy = image.size.height/ScreenHeight;
    float ratiox = image.size.width/ScreenWidth;
    NSLog(@"%f,%f",kBgImgX*ratiox,kBgImgY*ratioy);

    CGRect subrect = CGRectMake((kBgImgX+100)*ratiox, (kBgImgY+100)*ratioy, kBgImgWidth*ratiox, kBgImgWidth*ratioy);
    
    CGImageRef imageRef = image.CGImage;
    
    CGImageRef subimageRef = CGImageCreateWithImageInRect(imageRef, subrect);
    
    UIGraphicsBeginImageContext(subrect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextDrawImage(context, CGRectMake(0, 0, subrect.size.width, subrect.size.height), subimageRef);
    
    UIImage  *im  = [UIImage imageWithCGImage:subimageRef scale:image.scale orientation:UIImageOrientationRight];
    UIGraphicsEndImageContext();
    NSLog(@"%f,%f",im.size.height,im.size.width);
    return im;
    
    
}

@end
