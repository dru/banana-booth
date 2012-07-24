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
    
    
    player = [[MPMoviePlayerController alloc] initWithContentURL: movieURL];
    [player prepareToPlay];
    [player.view setFrame: self.view.bounds];
    [self.view insertSubview: player.view belowSubview: back_button];
    
    player.view.userInteractionEnabled = NO;

    player.controlStyle = MPMovieControlStyleNone;
//    player.shouldAutoplay = YES;
//    [player setFullscreen:YES animated:YES];
    
    [player play];
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
    [super viewDidUnload];
}
@end
