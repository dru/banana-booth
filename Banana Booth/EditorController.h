//
//  EditorController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditorController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *start_button;
@property (weak, nonatomic) IBOutlet UIImageView *user_photo;
@property (weak, nonatomic) UIImage *image;
- (IBAction)back_click:(id)sender;

@end
