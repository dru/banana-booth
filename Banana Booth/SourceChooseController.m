//
//  SourceChooseController.m
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import "SourceChooseController.h"
#import "EditorController.h"

#import <MobileCoreServices/UTCoreTypes.h>


@interface SourceChooseController ()

@end

@implementation SourceChooseController
@synthesize gallery_button;
@synthesize camera_button;
@synthesize selected_image;

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

    [gallery_button setImage:[UIImage imageNamed:@"Button_Gallery_down.png"] forState:UIControlStateHighlighted];
    [camera_button setImage:[UIImage imageNamed:@"Button_Camera_down.png"] forState:UIControlStateHighlighted];

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
    [self setGallery_button:nil];
    [self setCamera_button:nil];
    [super viewDidUnload];
}
- (IBAction)camera_button_click:(id)sender {
    // make sure this device has a camera
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        picker.allowsEditing = NO;
        picker.showsCameraControls = YES;
        
        picker.delegate = self;
        
        [self presentModalViewController:picker animated:YES];
        
        /*
         This seems like it should work. But it does not.
         
         CGRect screenRect = [[UIScreen mainScreen] bounds];
         UIImageView *overlay = [[UIImageView alloc] initWithImage:self.overlayImage];
         */
        
        // Overlay view will be the size of the screen
        UIImageView *overlay = [[UIImageView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        
        // with an image sized to fit in the viewfinder window
        // (Resize using Trevor Harmon's UIImage+ categories)
        overlay.image = [UIImage imageNamed:@"Camera_grid.png"];
        
        // tell the view to put the image at the top, and make it transparent
        overlay.contentMode = UIViewContentModeTop;
        overlay.alpha = 0.5f;
        
        picker.cameraOverlayView = overlay;
        
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Camera Unavailable"
                                     message:@"The camera is unavailable on this device. Add some images from your photo library."
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] show];
    }

}

- (IBAction)gallery_button_click:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    picker.delegate = self;
    
    [self presentModalViewController:picker animated:YES];
}

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    self.selected_image = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];

    [self performSegueWithIdentifier: @"editor" sender:self];
    [picker dismissModalViewControllerAnimated:YES];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{    
    EditorController *editor = [segue destinationViewController];
    
    editor.image =  self.selected_image;
}

@end
