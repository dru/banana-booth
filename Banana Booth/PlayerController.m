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

- (void)exportDidFinish:(AVAssetExportSession*)session;

@property(nonatomic, strong) AVAsset *asset;
@property(nonatomic, strong) NSMutableArray *currentDocument;
@property(nonatomic, strong) NSMutableArray *currentLine;
@property(nonatomic, strong) NSDictionary *animationValues;

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

@property(nonatomic, strong) MPMoviePlayerController *player;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation PlayerController
@synthesize back_button;

- (void)parserDidBeginDocument:(CHCSVParser *)parser {
  self.currentDocument = [[NSMutableArray alloc] init];
}
- (void)parserDidEndDocument:(CHCSVParser *)parser {
  NSLog(@"DONE parsing");
  NSMutableDictionary *animationValues = [[NSMutableDictionary alloc] init];
  for (NSArray *row in self.currentDocument) {
    [animationValues setObject:[row subarrayWithRange:NSMakeRange(1, [row count]-1)] forKey:[row objectAtIndex:0]];
  }
  self.currentDocument = nil;
  self.animationValues = [animationValues copy];
  dispatch_group_leave(self.dispatchGroup);
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
  f.decimalSeparator = @".";
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
  self.cancelled = YES;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
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


- (void)viewDidLoad
{
  [super viewDidLoad];

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
  
  self.dispatchGroup = dispatch_group_create();
  
  dispatch_group_enter(self.dispatchGroup);
  
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
      if (!success) {
        self.cancelled = YES;
        [self readingAndWritingDidFinishSuccessfully:success withError:localError];
      }
      NSLog(@"DONE setup");
      dispatch_group_leave(self.dispatchGroup);
    });
  }];
  
  dispatch_group_enter(self.dispatchGroup);
  
  NSString *animationCSVPath = [[NSBundle mainBundle] pathForResource:@"animation" ofType:@"csv"];
  
  CHCSVParser *parser = [[CHCSVParser alloc] initWithContentsOfCSVFile:animationCSVPath];
  parser.delegate = self;
  [parser parse];
  
  dispatch_group_notify(self.dispatchGroup, self.mainSerializationQueue, ^{
    if(!self.cancelled) {
      BOOL success = YES;
      NSError *localError;
      NSLog(@"START");
      success = [self startAssetReaderAndWriter:&localError];
      if (!success ) {
        [self readingAndWritingDidFinishSuccessfully:success withError:localError];
      }
    }
  });
  
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

            CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CVPixelBufferRef modifiedBuffer = [self processFrame:self.frameCounter withSampleBuffer:sampleBuffer];
            self.frameCounter += 1;
            
            //BOOL success = [self.assetWriterVideoInput appendSampleBuffer:sampleBuffer];
            BOOL success = [self.assetWriterAdaptor appendPixelBuffer:modifiedBuffer withPresentationTime:presentationTime];
            CFRelease(sampleBuffer);
            sampleBuffer = NULL;
            completedOrFailed = !success;
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self.progressView setProgress:(float)self.frameCounter/485.0];
              });
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
      [self playMovie];
    });
  }
}


- (CVPixelBufferRef) processFrame:(NSUInteger)frame withSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  // Lock the base address of the pixel buffer.
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  
  // Get the number of bytes per row for the pixel buffer.
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  // Get the pixel buffer width and height.
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  
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
  CGContextRef context = CGBitmapContextCreate(baseAddress, width,
                                               height, 8, bytesPerRow, colorSpace,
                                               kCGImageAlphaNoneSkipFirst);
  NSParameterAssert(context);
  
  [self drawFrame: (NSUInteger)frame withContext:(CGContextRef)context];
  
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  return imageBuffer;
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
  [self setFaceImage:nil];
    [super viewDidUnload];
}

-(void) playMovie {
  
    self.player = [[MPMoviePlayerController alloc] initWithContentURL: self.outputURL];
    [self.player prepareToPlay];
    [self.player.view setFrame: self.view.bounds];  // player's frame must match parent's
    [self.view addSubview: self.player.view];
    
    self.player.controlStyle = MPMovieControlStyleNone;
    
    [self.player play];
  
  // Register for the playback finished notification
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(movieFinishedCallback:)
                                               name: MPMoviePlayerPlaybackDidFinishNotification
                                             object: self.player];
  
}

// When the movie is done, release the controller.
-(void) movieFinishedCallback: (NSNotification*) aNotification
{
  [[NSNotificationCenter defaultCenter]
   removeObserver: self
   name: MPMoviePlayerPlaybackDidFinishNotification
   object: self.player];
  
  [self.player.view removeFromSuperview];
  self.player = nil;
}

- (void) drawFrame:(NSUInteger)frame withContext:(CGContextRef)context
{
  CGContextRetain(context);
  NSArray *values = [self.animationValues objectForKey:[NSNumber numberWithUnsignedInteger:frame]];

  if (values) {
    NSLog(@"%d", frame);
    
    size_t imgWidth = CGImageGetWidth(self.faceImage);
    size_t imgHeight = CGImageGetHeight(self.faceImage);
    
    CGContextTranslateCTM(context, 0.0, (CGFloat)CGBitmapContextGetHeight(context));
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextConcatCTM(context, CGAffineTransformMake([values[0] floatValue], [values[1] floatValue], [values[2] floatValue], [values[3] floatValue], [values[4] floatValue], [values[5] floatValue]));
    CGContextScaleCTM(context, 1.0, -1.0);

    CGFloat scale = MIN(100.0/(CGFloat)imgWidth, 140.0/(CGFloat)imgHeight);
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, (CGFloat)imgWidth / -2.0, (CGFloat)imgHeight / -2.0);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, imgWidth, imgHeight), self.faceImage);
  } else {
    NSLog(@"-");
  }
  CGContextRelease(context);
  //self.animationValues
}

@end
