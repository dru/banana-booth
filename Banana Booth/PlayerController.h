//
//  PlayerController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "mediaplayer/MPMoviePlayerController.h"


@interface PlayerController : UIViewController
- (IBAction)back_click:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *back_button;

@property (weak, nonatomic) IBOutlet UIImageView *face;
@property (weak, nonatomic) UIImage *face_image;
@property (nonatomic) CGRect face_rect;

@property (strong, nonatomic) MPMoviePlayerController *player;

@end
