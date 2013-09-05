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

@interface PlayerController ()

@end

@implementation PlayerController
@synthesize back_button;
@synthesize player;
@synthesize face_image;
@synthesize face_rect;
@synthesize face;


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
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *moviePath = [bundle pathForResource:@"Naked_banana_dance1" ofType:@"mov"];
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    face.image = face_image;
    face.frame = face_rect;
    
    CGRect rect = face.frame;
    rect.origin.x = 0;
    rect.origin.y = 0;
    rect.size.width = rect.size.width/2;
    rect.size.height =  rect.size.height/2;
    
    face.frame = rect;
    
//    UIGraphicsBeginImageContext(self.bounds.size);
//    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
//    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
    player = [[MPMoviePlayerController alloc] initWithContentURL: movieURL];
    [player prepareToPlay];
    [player.view setFrame: self.view.bounds];
    player.allowsAirPlay = NO;
    [self.view insertSubview: player.view belowSubview: back_button];
    
    [face.layer addAnimation:[self animate] forKey:nil];
    
    player.view.userInteractionEnabled = NO;

    player.controlStyle = MPMovieControlStyleNone;
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
    
    animation.duration = 10.2;
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
