//
//  PlayerController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MPMoviePlayerController.h>
#import "CHCSVParser.h"


@interface PlayerController : UIViewController <CHCSVParserDelegate>
- (IBAction)back_click:(id)sender;

@property (weak, nonatomic) IBOutlet UIImageView *faceImageView;
@property (weak, nonatomic) IBOutlet UIButton *back_button;
@property (nonatomic) CGImageRef faceImage;

@end
