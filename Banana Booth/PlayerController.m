//
//  PlayerController.m
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import "PlayerController.h"

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
    NSString *moviePath = [bundle pathForResource:@"Animation_Naked_Banana_v1_1" ofType:@"mov"];
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    face.image = face_image;
    face.frame = face_rect;
    
    CGRect rect = face.frame;
    rect.origin.x = 160;
    rect.origin.y = 200;
    rect.size.width = rect.size.width/2;
    rect.size.height =  rect.size.height/2;
    
    face.frame = rect;
    
    player = [[MPMoviePlayerController alloc] initWithContentURL: movieURL];
    [player prepareToPlay];
    [player.view setFrame: self.view.bounds];
    [self.view insertSubview: player.view belowSubview: back_button];
    
    player.view.userInteractionEnabled = NO;

    player.controlStyle = MPMovieControlStyleNone;
//    player.shouldAutoplay = YES;
//    [player setFullscreen:YES animated:YES];
//    [player initWithContentURL];
//    [player play];
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
