//
//  MainController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 19.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MainController : UIViewController <UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *start_button;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollview;

@property int page;

@property (weak, nonatomic) IBOutlet UIButton *right_button;
@property (weak, nonatomic) IBOutlet UIButton *left_button;

- (IBAction)right_touch:(id)sender;
- (IBAction)left_touch:(id)sender;

@property (weak, nonatomic) IBOutlet UIView *footer;
@property (weak, nonatomic) IBOutlet UIImageView *titleImage;

@end
