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

@property(nonatomic, strong) AVAsset *asset;
@property(nonatomic, strong) NSMutableArray *currentDocument;
@property(nonatomic, strong) NSMutableArray *currentLine;
@property(nonatomic, strong) NSArray *animationValues;
@property(nonatomic) NSUInteger totalFrames;

@property(nonatomic) dispatch_queue_t mainSerializationQueue;
@property(nonatomic) dispatch_queue_t rwAudioSerializationQueue;
@property(nonatomic) dispatch_queue_t rwVideoSerializationQueue;
@property(nonatomic) dispatch_group_t dispatchGroup;

@property(nonatomic) BOOL cancelled;
@property(nonatomic) BOOL audioFinished;
@property(nonatomic) BOOL videoFinished;
@property(nonatomic, strong) NSURL* outputURL;

@property(nonatomic, strong) AVAssetReader *assetReader;
@property(nonatomic, strong) AVAssetWriter *assetWriter;
@property(nonatomic, strong) AVAssetWriterInput* assetWriterAudioInput;
@property(nonatomic, strong) AVAssetWriterInput* assetWriterVideoInput;
@property(nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor* assetWriterAdaptor;
@property(nonatomic, strong) AVAssetReaderOutput* assetReaderVideoOutput;
@property(nonatomic, strong) AVAssetReaderOutput* assetReaderAudioOutput;
@property(nonatomic) NSUInteger frameCounter;

@property(nonatomic) CGImageRef obamaIamge;

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

/*
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
*/
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
  
  UIImage *obamaImage = [UIImage imageNamed:@"obama2.png"];
  self.obamaIamge = [obamaImage CGImage];

  NSBundle *bundle = [NSBundle mainBundle];
  NSString *moviePath = [bundle pathForResource:@"bonana" ofType:@"mov"];
  NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
  self.asset = [[AVURLAsset alloc]initWithURL:movieURL options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES }];
  
  NSString *serializationQueueDescription = [NSString stringWithFormat:@"%@ serialization queue", self];
  // Create the main serialization queue.
  self.mainSerializationQueue = dispatch_queue_create([serializationQueueDescription UTF8String], NULL);
  NSString *rwAudioSerializationQueueDescription = [NSString stringWithFormat:@"%@ rw audio serialization queue", self];
  // Create the serialization queue to use for reading and writing the audio data.
  self.rwAudioSerializationQueue = dispatch_queue_create([rwAudioSerializationQueueDescription UTF8String], NULL);
  NSString *rwVideoSerializationQueueDescription = [NSString stringWithFormat:@"%@ rw video serialization queue", self];
  // Create the serialization queue to use for reading and writing the video data.
  self.rwVideoSerializationQueue = dispatch_queue_create([rwVideoSerializationQueueDescription UTF8String], NULL);
  
  self.cancelled = NO;

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:@"FinalVideo.mov"];
  self.outputURL = [NSURL fileURLWithPath:myPathDocs];
  
  // Asynchronously load the tracks of the asset you want to read.
  [self.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
    // Once the tracks have finished loading, dispatch the work to the main serialization queue.
    dispatch_async(self.mainSerializationQueue, ^{
      // Due to asynchronous nature, check to see if user has already cancelled.
      if (self.cancelled)
        return;
      BOOL success = YES;
      NSError *localError = nil;
      // Check for success of loading the assets tracks.
      success = ([self.asset statusOfValueForKey:@"tracks" error:&localError] == AVKeyValueStatusLoaded);
      if (success)
      {
        // If the tracks loaded successfully, make sure that no file exists at the output path for the asset writer.
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *localOutputPath = [self.outputURL path];
        if ([fm fileExistsAtPath:localOutputPath])
          success = [fm removeItemAtPath:localOutputPath error:&localError];
      }
      if (success)
        success = [self setupAssetReaderAndAssetWriter:&localError];
      if (success)
        success = [self startAssetReaderAndWriter:&localError];
      if (!success)
        [self readingAndWritingDidFinishSuccessfully:success withError:localError];
    });
  }];
}

- (BOOL)setupAssetReaderAndAssetWriter:(NSError **)outError
{
  // Create and initialize the asset reader.
  self.assetReader = [[AVAssetReader alloc] initWithAsset:self.asset error:outError];
  BOOL success = (self.assetReader != nil);
  if (success)
  {
    // If the asset reader was successfully initialized, do the same for the asset writer.
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.outputURL fileType:AVFileTypeQuickTimeMovie error:outError];
    success = (self.assetWriter != nil);
  }
  
  if (success)
  {
    // If the reader and writer were successfully initialized, grab the audio and video asset tracks that will be used.
    AVAssetTrack *assetAudioTrack = nil, *assetVideoTrack = nil;
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    if ([audioTracks count] > 0)
      assetAudioTrack = [audioTracks objectAtIndex:0];
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] > 0)
      assetVideoTrack = [videoTracks objectAtIndex:0];
    
    if (assetAudioTrack)
    {
      // If there is an audio track to read, set the decompression settings to Linear PCM and create the asset reader output.
      NSDictionary *decompressionAudioSettings = @{ AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM] };
      self.assetReaderAudioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetAudioTrack outputSettings:decompressionAudioSettings];
      [self.assetReader addOutput:self.assetReaderAudioOutput];
      // Then, set the compression settings to 128kbps AAC and create the asset writer input.
      AudioChannelLayout stereoChannelLayout = {
        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
        .mChannelBitmap = 0,
        .mNumberChannelDescriptions = 0
      };
      NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
      NSDictionary *compressionAudioSettings = @{
                                                 AVFormatIDKey         : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
                                                 AVEncoderBitRateKey   : [NSNumber numberWithInteger:128000],
                                                 AVSampleRateKey       : [NSNumber numberWithInteger:44100],
                                                 AVChannelLayoutKey    : channelLayoutAsData,
                                                 AVNumberOfChannelsKey : [NSNumber numberWithUnsignedInteger:2]
                                                 };
      self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:[assetAudioTrack mediaType] outputSettings:compressionAudioSettings];
      [self.assetWriter addInput:self.assetWriterAudioInput];
    }
    
    if (assetVideoTrack)
    {
      // If there is a video track to read, set the decompression settings for YUV and create the asset reader output.
      NSDictionary *decompressionVideoSettings = @{
                                                   (id)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB],
                                                   (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                                                   };
      self.assetReaderVideoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetVideoTrack outputSettings:decompressionVideoSettings];
      [self.assetReader addOutput:self.assetReaderVideoOutput];
      CMFormatDescriptionRef formatDescription = NULL;
      // Grab the video format descriptions from the video track and grab the first one if it exists.
      NSArray *videoFormatDescriptions = [assetVideoTrack formatDescriptions];
      if ([videoFormatDescriptions count] > 0)
        formatDescription = (__bridge CMFormatDescriptionRef)[videoFormatDescriptions objectAtIndex:0];
      CGSize trackDimensions = {
        .width = 0.0,
        .height = 0.0,
      };
      // If the video track had a format description, grab the track dimensions from there. Otherwise, grab them direcly from the track itself.
      if (formatDescription)
        trackDimensions = CMVideoFormatDescriptionGetPresentationDimensions(formatDescription, false, false);
      else
        trackDimensions = [assetVideoTrack naturalSize];
      NSDictionary *compressionSettings = nil;
      // If the video track had a format description, attempt to grab the clean aperture settings and pixel aspect ratio used by the video.
      if (formatDescription)
      {
        NSDictionary *cleanAperture = nil;
        NSDictionary *pixelAspectRatio = nil;
        CFDictionaryRef cleanApertureFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_CleanAperture);
        if (cleanApertureFromCMFormatDescription)
        {
          cleanAperture = @{
                            AVVideoCleanApertureWidthKey            : (id)CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureWidth),
                            AVVideoCleanApertureHeightKey           : (id)CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureHeight),
                            AVVideoCleanApertureHorizontalOffsetKey : (id)CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureHorizontalOffset),
                            AVVideoCleanApertureVerticalOffsetKey   : (id)CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureVerticalOffset)
                            };
        }
        CFDictionaryRef pixelAspectRatioFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_PixelAspectRatio);
        if (pixelAspectRatioFromCMFormatDescription)
        {
          pixelAspectRatio = @{
                               AVVideoPixelAspectRatioHorizontalSpacingKey : (id)CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing),
                               AVVideoPixelAspectRatioVerticalSpacingKey   : (id)CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing)
                               };
        }
        // Add whichever settings we could grab from the format description to the compression settings dictionary.
        if (cleanAperture || pixelAspectRatio)
        {
          NSMutableDictionary *mutableCompressionSettings = [NSMutableDictionary dictionary];
          if (cleanAperture)
            [mutableCompressionSettings setObject:cleanAperture forKey:AVVideoCleanApertureKey];
          if (pixelAspectRatio)
            [mutableCompressionSettings setObject:pixelAspectRatio forKey:AVVideoPixelAspectRatioKey];
          compressionSettings = mutableCompressionSettings;
        }
      }
      // Create the video settings dictionary for H.264.
      NSMutableDictionary *videoSettings = [@{
                                                                     AVVideoCodecKey  : AVVideoCodecH264,
                                                                     AVVideoWidthKey  : [NSNumber numberWithDouble:trackDimensions.width],
                                                                     AVVideoHeightKey : [NSNumber numberWithDouble:trackDimensions.height]
                                                                     } mutableCopy];
      // Put the compression settings into the video settings dictionary if we were able to grab them.
      if (compressionSettings)
        [videoSettings setObject:compressionSettings forKey:AVVideoCompressionPropertiesKey];
      // Create the asset writer input and add it to the asset writer.
      self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:[assetVideoTrack mediaType] outputSettings:videoSettings];
      
      NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
      self.assetWriterAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.assetWriterVideoInput sourcePixelBufferAttributes:bufferAttributes];
      [self.assetWriter addInput:self.assetWriterVideoInput];
    }
  }
  return success;
}

- (BOOL)startAssetReaderAndWriter:(NSError **)outError
{
  BOOL success = YES;
  // Attempt to start the asset reader.
  success = [self.assetReader startReading];
  if (!success)
    *outError = [self.assetReader error];
  if (success)
  {
    // If the reader started successfully, attempt to start the asset writer.
    success = [self.assetWriter startWriting];
    if (!success)
      *outError = [self.assetWriter error];
  }
  
  if (success)
  {
    // If the asset reader and writer both started successfully, create the dispatch group where the reencoding will take place and start a sample-writing session.
    self.dispatchGroup = dispatch_group_create();
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    self.audioFinished = NO;
    self.videoFinished = NO;
    
    if (self.assetWriterAudioInput)
    {
      // If there is audio to reencode, enter the dispatch group before beginning the work.
      dispatch_group_enter(self.dispatchGroup);
      // Specify the block to execute when the asset writer is ready for audio media data, and specify the queue to call it on.
      [self.assetWriterAudioInput requestMediaDataWhenReadyOnQueue:self.rwAudioSerializationQueue usingBlock:^{
        // Because the block is called asynchronously, check to see whether its task is complete.
        if (self.audioFinished)
          return;
        BOOL completedOrFailed = NO;
        // If the task isn't complete yet, make sure that the input is actually ready for more media data.
        while ([self.assetWriterAudioInput isReadyForMoreMediaData] && !completedOrFailed)
        {
          // Get the next audio sample buffer, and append it to the output file.
          CMSampleBufferRef sampleBuffer = [self.assetReaderAudioOutput copyNextSampleBuffer];
          if (sampleBuffer != NULL)
          {
            BOOL success = [self.assetWriterAudioInput appendSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
            sampleBuffer = NULL;
            completedOrFailed = !success;
          }
          else
          {
            completedOrFailed = YES;
          }
        }
        if (completedOrFailed)
        {
          // Mark the input as finished, but only if we haven't already done so, and then leave the dispatch group (since the audio work has finished).
          BOOL oldFinished = self.audioFinished;
          self.audioFinished = YES;
          if (oldFinished == NO)
          {
            [self.assetWriterAudioInput markAsFinished];
          }
          dispatch_group_leave(self.dispatchGroup);
        }
      }];
    }
    
    if (self.assetWriterVideoInput)
    {
      // If we had video to reencode, enter the dispatch group before beginning the work.

      dispatch_group_enter(self.dispatchGroup);
      self.frameCounter = 0;
      // Specify the block to execute when the asset writer is ready for video media data, and specify the queue to call it on.
      [self.assetWriterVideoInput requestMediaDataWhenReadyOnQueue:self.rwVideoSerializationQueue usingBlock:^{
        // Because the block is called asynchronously, check to see whether its task is complete.
        if (self.videoFinished)
          return;
        BOOL completedOrFailed = NO;
        // If the task isn't complete yet, make sure that the input is actually ready for more media data.
        while ([self.assetWriterVideoInput isReadyForMoreMediaData] && !completedOrFailed)
        {
          // Get the next video sample buffer, and append it to the output file.
          CMSampleBufferRef sampleBuffer = [self.assetReaderVideoOutput copyNextSampleBuffer];
          if (sampleBuffer != NULL)
          {
            self.frameCounter += 1;
            CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CVPixelBufferRef modifiedBuffer = [self process:sampleBuffer];
            
            NSLog(@"Presentation Time: %lld/%d", presentationTime.value, presentationTime.timescale);
            //BOOL success = [self.assetWriterVideoInput appendSampleBuffer:sampleBuffer];
            BOOL success = [self.assetWriterAdaptor appendPixelBuffer:modifiedBuffer withPresentationTime:presentationTime];
            CFRelease(sampleBuffer);
            sampleBuffer = NULL;
            completedOrFailed = !success;
          }
          else
          {
            completedOrFailed = YES;
          }
        }
        if (completedOrFailed)
        {
          // Mark the input as finished, but only if we haven't already done so, and then leave the dispatch group (since the video work has finished).
          BOOL oldFinished = self.videoFinished;
          self.videoFinished = YES;
          if (oldFinished == NO)
          {
            [self.assetWriterVideoInput markAsFinished];
          }
          dispatch_group_leave(self.dispatchGroup);
        }
      }];
    }
    // Set up the notification that the dispatch group will send when the audio and video work have both finished.
    dispatch_group_notify(self.dispatchGroup, self.mainSerializationQueue, ^{
      BOOL finalSuccess = YES;
      NSError *finalError = nil;
      // Check to see if the work has finished due to cancellation.
      if (self.cancelled)
      {
        // If so, cancel the reader and writer.
        [self.assetReader cancelReading];
        [self.assetWriter cancelWriting];
      }
      else
      {
        // If cancellation didn't occur, first make sure that the asset reader didn't fail.
        if ([self.assetReader status] == AVAssetReaderStatusFailed)
        {
          finalSuccess = NO;
          finalError = [self.assetReader error];
        }
        // If the asset reader didn't fail, attempt to stop the asset writer and check for any errors.
        if (finalSuccess)
        {
          [self.assetWriter endSessionAtSourceTime:self.asset.duration];
          finalSuccess = [self.assetWriter finishWriting];
          if (!finalSuccess)
            finalError = [self.assetWriter error];
        }
      }
      // Call the method to handle completion, and pass in the appropriate parameters to indicate whether reencoding was successful.
      [self readingAndWritingDidFinishSuccessfully:finalSuccess withError:finalError];
    });
  }
  // Return success here to indicate whether the asset reader and writer were started successfully.
  return success;
}

- (void)readingAndWritingDidFinishSuccessfully:(BOOL)success withError:(NSError *)error
{
  if (!success)
  {
    // If the reencoding process failed, we need to cancel the asset reader and writer.
    [self.assetReader cancelReading];
    [self.assetWriter cancelWriting];
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                     delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
      [alert show];
      NSLog(@"ERROR: %@", error);
    });
  }
  else
  {
    // Reencoding was successful, reset booleans.
    self.cancelled = NO;
    self.videoFinished = NO;
    self.audioFinished = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"SUCCESS");
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                     delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
      [alert show];
    });
  }
}

- (CMSampleBufferRef) modifySampleBuffer:(CMSampleBufferRef)sampleBuffer
{
//  UIImage *image = [self sampleBufferToImage:sampleBuffer];
//  image = [self modifyImage: image];
//  sampleBuffer = [self imageToSampleBuffer:image];
  return sampleBuffer;
}

- (CVPixelBufferRef) process:(CMSampleBufferRef) sampleBuffer
{
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  // Lock the base address of the pixel buffer.
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  
  // Get the number of bytes per row for the pixel buffer.
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  // Get the pixel buffer width and height.
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  
  NSLog(@"H: %zd, W: %zd, BPR: %zd", height, width, bytesPerRow);
  
  // Create a device-dependent RGB color space.
  static CGColorSpaceRef colorSpace = NULL;
  if (colorSpace == NULL) {
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
      // Handle the error appropriately.
      return nil;
    }
  }
  
  // Get the base address of the pixel buffer.
  void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
  // Get the data size for contiguous planes of the pixel buffer.
  size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
  
  // Create a Quartz direct-access data provider that uses data we supply.
  CGDataProviderRef dataProvider =
  CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
  // Create a bitmap image from data supplied by the data provider.
  CGImageRef cgImage =
  CGImageCreate(width, height, 8, 32, bytesPerRow,
                colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Little,
                dataProvider, NULL, true, kCGRenderingIntentDefault);

  
  
  
  
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];
  CVPixelBufferRef outBuffer = NULL;
  
  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width,
                                        height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) options,
                                        &outBuffer);
  NSParameterAssert(status == kCVReturnSuccess && outBuffer != NULL);
  
  CVPixelBufferLockBaseAddress(outBuffer, 0);
  void *pxdata = CVPixelBufferGetBaseAddress(outBuffer);
  NSParameterAssert(pxdata != NULL);
  
  CGContextRef context = CGBitmapContextCreate(pxdata, width,
                                               height, 8, 4*width, colorSpace,
                                               kCGImageAlphaNoneSkipLast);
  NSParameterAssert(context);
  CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), cgImage);
  CGContextDrawImage(context, CGRectMake(100.0, 100.0, CGImageGetWidth(self.obamaIamge), CGImageGetHeight(self.obamaIamge)), self.obamaIamge);

  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(outBuffer, 0);
  
  CGImageRelease(cgImage);
  CGDataProviderRelease(dataProvider);
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  return outBuffer;
}

- (UIImage *) modifyImage:(UIImage *)image
{
  return image;
}

- (CMSampleBufferRef) imageToSampleBuffer:(UIImage *)image
{
  CMSampleBufferRef r = NULL;
  return r;
}

- (void)cancel
{
  // Handle cancellation asynchronously, but serialize it with the main queue.
  dispatch_async(self.mainSerializationQueue, ^{
    // If we had audio data to reencode, we need to cancel the audio work.
    if (self.assetWriterAudioInput)
    {
      // Handle cancellation asynchronously again, but this time serialize it with the audio queue.
      dispatch_async(self.rwAudioSerializationQueue, ^{
        // Update the Boolean property indicating the task is complete and mark the input as finished if it hasn't already been marked as such.
        BOOL oldFinished = self.audioFinished;
        self.audioFinished = YES;
        if (oldFinished == NO)
        {
          [self.assetWriterAudioInput markAsFinished];
        }
        // Leave the dispatch group since the audio work is finished now.
        dispatch_group_leave(self.dispatchGroup);
      });
    }
    
    if (self.assetWriterVideoInput)
    {
      // Handle cancellation asynchronously again, but this time serialize it with the video queue.
      dispatch_async(self.rwVideoSerializationQueue, ^{
        // Update the Boolean property indicating the task is complete and mark the input as finished if it hasn't already been marked as such.
        BOOL oldFinished = self.videoFinished;
        self.videoFinished = YES;
        if (oldFinished == NO)
        {
          [self.assetWriterVideoInput markAsFinished];
        }
        // Leave the dispatch group, since the video work is finished now.
        dispatch_group_leave(self.dispatchGroup);
      });
    }
    // Set the cancelled Boolean property to YES to cancel any work on the main queue as well.
    self.cancelled = YES;
  });
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
