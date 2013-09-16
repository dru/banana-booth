//
//  PlayerController.m
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import "PlayerController.h"   
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface PlayerController ()

- (void)videoOutput;
- (void)exportDidFinish:(AVAssetExportSession*)session;
- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition size:(CGSize)size duration:(Float64)duration;

@property(nonatomic, strong) AVAsset *videoAsset;
@property(nonatomic, strong) NSMutableArray *currentDocument;
@property(nonatomic, strong) NSMutableArray *currentLine;
@property(nonatomic, strong) NSArray *animationValues;
@property(nonatomic) NSUInteger totalFrames;

@end

@implementation PlayerController
@synthesize back_button;
@synthesize player;
@synthesize face_image;
@synthesize face_rect;
@synthesize face;

- (void)parserDidBeginDocument:(CHCSVParser *)parser {
  self.currentDocument = [[NSMutableArray alloc] init];
}
- (void)parserDidEndDocument:(CHCSVParser *)parser {
  NSArray *lastLine = [self.currentDocument objectAtIndex:[self.currentDocument count] - 1];
  [self.currentDocument removeObjectAtIndex:[self.currentDocument count] - 1];
  self.totalFrames = [[lastLine objectAtIndex:0] integerValue];
  self.animationValues = [self.currentDocument copy];
  self.currentDocument = nil;
}

- (void)parser:(CHCSVParser *)parser didBeginLine:(NSUInteger)recordNumber {
  self.currentLine = [[NSMutableArray alloc] init];
}
- (void)parser:(CHCSVParser *)parser didEndLine:(NSUInteger)recordNumber {
  [self.currentDocument addObject:[self.currentLine copy]];
  self.currentLine = nil;
}

- (void)parser:(CHCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex {
  NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
  [f setNumberStyle:NSNumberFormatterDecimalStyle];
  NSNumber * number = [f numberFromString:field];
  if (number) {
    [self.currentLine addObject:number];
  } else {
    [self.currentLine addObject:[[NSNull alloc] init]];
  }

}

- (void)parser:(CHCSVParser *)parser didFailWithError:(NSError *)error {
  NSLog(@"Error parsing CSV: %@", error);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)videoOutput
{
  // 1 - Early exit if there's no video file selected
  if (!self.videoAsset) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please Load a Video Asset First"
                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    return;
  }
  
  // 2 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
  AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
  
  // 3 - Video track
  AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];

  [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, self.videoAsset.duration)
                      ofTrack:[[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                       atTime:kCMTimeZero error:nil];
  
  // 3.1 - Create AVMutableVideoCompositionInstruction
  AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
  mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, self.videoAsset.duration);
  
  // 3.2 - Create an AVMutableVideoCompositionLayerInstruction for the video track and fix the orientation.
  AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  AVAssetTrack *videoAssetTrack = [[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
  
  // 3.3 - Add instructions
  mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
  
  AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
  
  CGSize naturalSize;

  naturalSize = videoAssetTrack.naturalSize;
  
  float renderWidth, renderHeight;
  renderWidth = naturalSize.width;
  renderHeight = naturalSize.height;
  mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
  mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
  mainCompositionInst.frameDuration = CMTimeMake(1, 30);
  
  
  [self applyVideoEffectsToComposition:mainCompositionInst size:naturalSize duration:CMTimeGetSeconds(self.videoAsset.duration)];
  
  // 4 - Get path
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"FinalVideo-%d.mov",arc4random() % 1000]];
  NSURL *url = [NSURL fileURLWithPath:myPathDocs];
  
  // 5 - Create exporter
  AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                    presetName:AVAssetExportPresetHighestQuality];
  exporter.outputURL=url;
  exporter.outputFileType = AVFileTypeQuickTimeMovie;
  exporter.shouldOptimizeForNetworkUse = NO;
  exporter.videoComposition = mainCompositionInst;
  [exporter exportAsynchronouslyWithCompletionHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self exportDidFinish:exporter];
    });
  }];
}

- (void)exportDidFinish:(AVAssetExportSession*)session {
  if (session.status == AVAssetExportSessionStatusCompleted) {
    NSURL *outputURL = session.outputURL;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
      [library writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
          if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
          } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                           delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
          }
        });
      }];
    }
  }
}

- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition size:(CGSize)size duration:(Float64) duration
{
  // 1
  UIImage *animationImage = [UIImage imageNamed:@"obama2.png"];
  CALayer *overlayLayer1 = [CALayer layer];
  overlayLayer1.anchorPoint = CGPointMake(0.0, 1.0);
  [overlayLayer1 setContents:(id)[animationImage CGImage]];
  overlayLayer1.frame = CGRectMake((size.width - animationImage.size.width)/2, (size.height - animationImage.size.height)/2, animationImage.size.width, animationImage.size.height);
  [overlayLayer1 setMasksToBounds:YES];
  
  NSString *animationCSVPath = [[NSBundle mainBundle] pathForResource:@"animation" ofType:@"csv"];
  
  CHCSVParser *parser = [[CHCSVParser alloc] initWithContentsOfCSVFile:animationCSVPath];
  parser.delegate = self;
  [parser parse];
  
  NSUInteger framesCount = [self.animationValues count];
  NSMutableArray *positionValues = [[NSMutableArray alloc] initWithCapacity:framesCount];
  NSMutableArray *positionTimes = [[NSMutableArray alloc] initWithCapacity:framesCount];
  NSMutableArray *rotationValues = [[NSMutableArray alloc] initWithCapacity:framesCount];
  NSMutableArray *scaleXValues = [[NSMutableArray alloc] initWithCapacity:framesCount];
  NSMutableArray *scaleYValues = [[NSMutableArray alloc] initWithCapacity:framesCount];
  NSMutableArray *opacityValues = [[NSMutableArray alloc] init];
  NSMutableArray *opacityTimes = [[NSMutableArray alloc] init];
  
  
  NSUInteger prevFrame = -1;
  BOOL firstFrame = YES;
  
  double time;
  
  for (NSArray *frame in self.animationValues) {
    NSUInteger frameNumber = [[frame objectAtIndex:0] integerValue];

    if (firstFrame) {
      if (frameNumber == 0) {
        [opacityValues addObject:@1.0];
        [opacityTimes addObject:@0.0];
      } else {
        [positionTimes addObject:@0.0];
        [scaleXValues addObject:@1.0];
        [scaleYValues addObject:@1.0];
        [rotationValues addObject:@0.0];
        [positionValues addObject:[NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)]];
      }
    }
    

    if (prevFrame + 1 != frameNumber) {
      time = ((double)(prevFrame + 1)) / (double)self.totalFrames;
      [opacityTimes addObject:[[NSNumber alloc] initWithDouble:time]];
      [opacityValues addObject:@0.0];
      time = ((double) frameNumber) / (double) self.totalFrames;
      [opacityTimes addObject:[[NSNumber alloc] initWithDouble:time]];
      [opacityValues addObject:@1.0];
    }

    NSNumber *x = [frame objectAtIndex:1];
    NSNumber *y = [[NSNumber alloc] initWithFloat:size.height - [[frame objectAtIndex:2] floatValue]];
    CGFloat rot = [[frame objectAtIndex:5] floatValue];
    
    [rotationValues addObject:[[NSNumber alloc] initWithFloat: (-1.0*rot / 180.0)*M_PI + M_PI/2.0]] ;
    [scaleXValues addObject:[frame objectAtIndex:3]];
    [scaleYValues addObject:[frame objectAtIndex:4]];

    [positionValues addObject:[NSValue valueWithCGPoint:CGPointMake([x floatValue], [y floatValue])]];
    time = (double)frameNumber/(double)self.totalFrames;

    [positionTimes addObject:[[NSNumber alloc] initWithDouble:time]];
    
    firstFrame = NO;
    prevFrame = frameNumber;
  }
  
  time = ((double)(prevFrame + 1)) / (double)self.totalFrames;
  [opacityValues addObject:@0.0];
  [opacityTimes addObject:[[NSNumber alloc] initWithDouble:time]];
  
  [positionTimes addObject:@1.0];
  [scaleXValues addObject:[scaleXValues lastObject]];
  [scaleYValues addObject:[scaleYValues lastObject]];
  [rotationValues  addObject:[rotationValues lastObject]];
  [positionValues addObject:[positionValues lastObject]];
  [opacityValues addObject:[opacityValues lastObject]];
  [opacityTimes addObject:@1.0];
  
  CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
  positionAnimation.duration = (CFTimeInterval)duration;
  positionAnimation.values = [positionValues copy];
  positionAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  positionAnimation.calculationMode = kCAAnimationDiscrete;
  positionAnimation.removedOnCompletion = NO;
  positionAnimation.keyTimes = [positionTimes copy];
  [overlayLayer1 addAnimation:positionAnimation forKey:@"position"];
  
  CAKeyframeAnimation *rotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation"];
  rotationAnimation.duration = (CFTimeInterval) duration;
  rotationAnimation.values = [rotationValues copy];
  rotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  rotationAnimation.calculationMode = kCAAnimationDiscrete;
  rotationAnimation.removedOnCompletion = NO;
  rotationAnimation.keyTimes = [positionTimes copy];
  [overlayLayer1 addAnimation:rotationAnimation forKey:@"rotation"];
  
  
  CAKeyframeAnimation *scaleXAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.x"];
  scaleXAnimation.duration = (CFTimeInterval) duration;
  scaleXAnimation.values = [scaleXValues copy];
  scaleXAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  scaleXAnimation.calculationMode = kCAAnimationDiscrete;
  scaleXAnimation.removedOnCompletion = NO;
  scaleXAnimation.keyTimes = [positionTimes copy];
  [overlayLayer1 addAnimation:scaleXAnimation forKey:@"scaleX"];

  CAKeyframeAnimation *scaleYAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];
  scaleYAnimation.duration = (CFTimeInterval) duration;
  scaleYAnimation.values = [scaleYValues copy];
  scaleYAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  scaleYAnimation.calculationMode = kCAAnimationDiscrete;
  scaleYAnimation.removedOnCompletion = NO;
  scaleYAnimation.keyTimes = [positionTimes copy];
  [overlayLayer1 addAnimation:scaleYAnimation forKey:@"scaleY"];
  
  CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
  opacityAnimation.duration = (CFTimeInterval) duration;
  opacityAnimation.values = [opacityValues copy];
  opacityAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  opacityAnimation.calculationMode = kCAAnimationDiscrete;
  opacityAnimation.removedOnCompletion = NO;
  opacityAnimation.keyTimes = [opacityTimes copy];
  [overlayLayer1 addAnimation:opacityAnimation forKey:@"opacity"];

  // 5
  CALayer *parentLayer = [CALayer layer];
  CALayer *videoLayer = [CALayer layer];
  parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
  videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
  [parentLayer addSublayer:videoLayer];
  [parentLayer addSublayer:overlayLayer1];
  
  composition.animationTool = [AVVideoCompositionCoreAnimationTool
                               videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  NSBundle *bundle = [NSBundle mainBundle];
  NSString *moviePath = [bundle pathForResource:@"bonana" ofType:@"mov"];
  NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
  self.videoAsset = [[AVURLAsset alloc]initWithURL:movieURL options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES }];
  //self.videoAsset = [AVAsset assetWithURL:movieURL];
  
  [self videoOutput];
  
//    UIGraphicsBeginImageContext(self.bounds.size);
//    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
//    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//  
//  player = [[MPMoviePlayerController alloc] initWithContentURL: movieURL];
//  [player prepareToPlay];
//  [player.view setFrame: self.view.bounds];
//  player.allowsAirPlay = NO;
//  [self.view insertSubview: player.view belowSubview: back_button];
//  
//  [face.layer addAnimation:[self animate] forKey:nil];
//  
//  player.view.userInteractionEnabled = NO;
//
//  player.controlStyle = MPMovieControlStyleNone;
//    player.shouldAutoplay = YES;
//    [player setFullscreen:YES animated:YES];
//    [player initWithContentURL];
//    [player play];
}

- (CAAnimation*) animate {
	CAKeyframeAnimation* animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.values = [NSArray arrayWithObjects:
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(44.60, 93.65, 0), 0, 1, 1, 1)],
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(44.60, 86.00, 0), 0, 1, 1, 1)],
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(27.65, 96.30, 0), -7.0, 1, 1, 1)],
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(200, 257, 0), 0, 1, 1, 1)],
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(-8, 17, 0), 0, 1, 1, 1)],
        [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DMakeTranslation(-8, 17, 0), 0, 1, 1, 1)],
    nil];	
    
    animation.duration = 5;
    return animation;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)back_click:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}
- (void)viewDidUnload {
    [self setBack_button:nil];
    [self setFace:nil];
    [super viewDidUnload];
}
@end
