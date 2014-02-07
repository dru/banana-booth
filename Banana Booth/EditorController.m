//
//  EditorController.m
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import "EditorController.h"
#import "UIImage+Resize.h"



@interface EditorController ()

@end

@implementation EditorController
@synthesize zoomBorder;

@synthesize leftButton;
@synthesize rightButton;
@synthesize topButton;
@synthesize bottomButton;

@synthesize start_button;
@synthesize user_photo;
@synthesize user_image_zoom;
@synthesize shapeLayer;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.user_photo.image = [self.image resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(320, 410) interpolationQuality:kCGInterpolationDefault];
    
    self.user_image_zoom.image = self.user_photo.image;

    zoomBorder.hidden = YES;
    user_image_zoom.hidden = YES;
    
    shapeLayer = [[CAShapeLayer alloc] init];

    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathAddArc(path, NULL, 0, 100, 50, 0, 2 * M_PI, NO);
    
    [shapeLayer setPath:path];
    [shapeLayer setFillColor:[[UIColor blackColor] CGColor]];
    [[user_image_zoom layer] setMask:shapeLayer];
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

- (void)viewDidUnload {
    [self setStart_button:nil];
    [self setUser_photo:nil];
    [self setLeftButton:nil];
    [self setRightButton:nil];
    [self setTopButton:nil];
    [self setBottomButton:nil];
    [self setZoomBorder:nil];
    [self setUser_image_zoom:nil];
    [super viewDidUnload];
}

- (IBAction)back_click:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)tuneButtonMoved:(id)sender forEvent:(UIEvent *)event {
    
    CGPoint point = [[[event allTouches] anyObject] locationInView:self.view];
    UIControl *control = sender;
    control.center = point;
    CGPoint zoomPoint = CGPointMake(point.x, point.y-100);
    zoomBorder.center = zoomPoint;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [shapeLayer setPosition:zoomPoint];
    [CATransaction commit];
}
- (IBAction)tuneButtonTouchEnd:(id)sender {

    
    [UIView animateWithDuration:0.1
                     animations:^{
                         CGPoint center = zoomBorder.center;
                         center.y += 50;
                         zoomBorder.alpha = 0.0;
                         user_image_zoom.alpha =  0.0;
                         zoomBorder.center = center;
                     }
                     completion:^(BOOL finished){
                         zoomBorder.hidden = YES;
                         user_image_zoom.hidden =  YES;
                     }
     ];
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        if ([[UIScreen mainScreen] scale] == 2.0) {
            UIGraphicsBeginImageContextWithOptions(newSize, YES, 2.0);
        } else {
            UIGraphicsBeginImageContext(newSize);
        }
    } else {
        UIGraphicsBeginImageContext(newSize);
    }
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


-(CGImageRef)makeMask {
    CGRect image_area = CGRectMake(
            leftButton.center.x,
            topButton.center.y,
            rightButton.center.x - leftButton.center.x,
            bottomButton.center.y -topButton.center.y
    );
    CGImageRef sub_image = CGImageCreateWithImageInRect(self.user_photo.image.CGImage, image_area);
    
    CIImage *inputImage = [[CIImage alloc] initWithCGImage:sub_image];
    CIImage *outputBrightnessImage = NULL;
    CIImage *outputTintImage = NULL;
    
    CIFilter *brightness = [CIFilter filterWithName:@"CIColorControls"];
    
    [brightness setDefaults];
    [brightness setValue: inputImage forKey:@"inputImage"];
    [brightness setValue:[NSNumber numberWithFloat: 1.5f] forKey:@"inputContrast"];
    [brightness setValue:[NSNumber numberWithFloat: 0.25f] forKey:@"inputBrightness"];
    
    outputBrightnessImage = [brightness valueForKey:@"outputImage"];
    
    CIFilter *monochrome = [CIFilter filterWithName:@"CIColorMonochrome"];
    
      [monochrome setDefaults];
    [monochrome setValue: outputBrightnessImage forKey:@"inputImage"];
    [monochrome setValue:[CIColor colorWithRed:1.0f green:0.78f blue:0.0f] forKey:@"inputColor"];
    [monochrome setValue:[NSNumber numberWithFloat: 1.0f] forKey:@"inputIntensity"];
    
    outputTintImage = [monochrome valueForKey:@"outputImage"];
  
    CIContext *context = [CIContext contextWithOptions:nil];
    
    UIImage *mask_image = [UIImage imageNamed:@"Result_face_mask_vertical"];
    mask_image =  [self imageWithImage:mask_image scaledToSize:CGSizeMake(image_area.size.width, image_area.size.height)];
  
    CGImageRef mask_ref = mask_image.CGImage;
    
    CGImageRef mask = CGImageMaskCreate(CGImageGetWidth(mask_ref),
                                            CGImageGetHeight(mask_ref),
                                            CGImageGetBitsPerComponent(mask_ref),
                                            CGImageGetBitsPerPixel(mask_ref),
                                            CGImageGetBytesPerRow(mask_ref),
                                            CGImageGetDataProvider(mask_ref), NULL, false);
  
    CGImageRef masked = CGImageCreateWithMask([context createCGImage:outputTintImage fromRect:outputTintImage.extent], mask);
    
    return masked;
  
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    PlayerController *player = [segue destinationViewController];
    
    player.faceImage = [self makeMask];
}

- (IBAction)tuneButtonTouch:(id)sender forEvent:(UIEvent *)event {
     
    CGPoint point = [[[event allTouches] anyObject] locationInView:self.view];
    CGPoint zoomPoint = CGPointMake(point.x, point.y - 50);
    zoomBorder.center = zoomPoint;
    
    zoomBorder.hidden = NO;
    user_image_zoom.hidden = NO;
    zoomBorder.alpha = 0.0;
    user_image_zoom.alpha = 0.0;
    
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGPoint center = zoomBorder.center;
    center.y -= 50;
    [shapeLayer setPosition:center];
    [CATransaction commit];
    
    
    [UIView animateWithDuration:0.1
                     animations:^{
                         CGPoint center = zoomBorder.center;
                         center.y -= 50;
                         zoomBorder.alpha = 1.0;
                         user_image_zoom.alpha = 1.0;
                         zoomBorder.center = center;
                     }
     ];
}
@end
