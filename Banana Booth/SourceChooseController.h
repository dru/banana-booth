//
//  SourceChooseController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SourceChooseController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *gallery_button;
@property (weak, nonatomic) IBOutlet UIButton *camera_button;
@property (strong, atomic) UIImage *selected_image;

- (IBAction)gallery_button_click:(id)sender;
- (IBAction)camera_button_click:(id)sender;

@end
