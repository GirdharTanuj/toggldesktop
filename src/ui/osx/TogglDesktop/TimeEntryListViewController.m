//
//  TimeEntryListViewController.m
//  Toggl Desktop on the Mac
//
//  Created by Tanel Lebedev on 19/09/2013.
//  Copyright (c) 2013 TogglDesktop developers. All rights reserved.
//

#import "TimeEntryListViewController.h"
#import "TimeEntryViewItem.h"
#import "TimerEditViewController.h"
#import "UIEvents.h"
#import "toggl_api.h"
#import "LoadMoreCell.h"
#import "TimeEntryCell.h"
#import "UIEvents.h"
#import "DisplayCommand.h"
#import "TimeEntryEditViewController.h"
#import "ConvertHexColor.h"
#include <Carbon/Carbon.h>
#import "TogglDesktop-Swift.h"
#import "TimeEntryCollectionView.h"

@interface TimeEntryListViewController () <NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>
@property (nonatomic, strong) IBOutlet TimerEditViewController *timerEditViewController;
@property (nonatomic, strong) TimeEntryDatasource *dataSource;
@property NSNib *nibTimeEntryCell;
@property NSNib *nibTimeEntryEditViewController;
@property NSNib *nibLoadMoreCell;
@property NSInteger defaultPopupHeight;
@property NSInteger defaultPopupWidth;
@property NSInteger addedHeight;
@property NSInteger minimumEditFormWidth;
@property BOOL runningEdit;
@property TimeEntryCell *selectedEntryCell;
@property (copy, nonatomic) NSString *lastSelectedGUID;
@property (nonatomic, strong) IBOutlet TimeEntryEditViewController *timeEntryEditViewController;
@property (nonatomic, strong) NSArray<TimeEntryViewItem *> *viewitems;
@property (weak) IBOutlet TimeEntryCollectionView *collectionView;

@end

@implementation TimeEntryListViewController

extern void *ctx;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self)
	{
		self.timerEditViewController = [[TimerEditViewController alloc]
										initWithNibName:@"TimerEditViewController" bundle:nil];
		self.timeEntryEditViewController = [[TimeEntryEditViewController alloc]
											initWithNibName:@"TimeEntryEditViewController" bundle:nil];
		[self.timerEditViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self.timeEntryEditViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

		self.viewitems = [[NSArray<TimeEntryViewItem *> alloc] init];

		self.nibTimeEntryCell = [[NSNib alloc] initWithNibNamed:@"TimeEntryCell"
														 bundle:nil];
		self.nibTimeEntryEditViewController = [[NSNib alloc] initWithNibNamed:@"TimeEntryEditViewController"
																	   bundle:nil];
		self.nibLoadMoreCell = [[NSNib alloc] initWithNibNamed:@"LoadMoreCell"
														bundle:nil];
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self initCommon];
	[self initCollectionView];
	[self setupEmptyLabel];
	[self initNotifications];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	[self.collectionView reloadData];
}

- (void)initCommon {
	[self.headerView addSubview:self.timerEditViewController.view];
	[self.timerEditViewController.view setFrame:self.headerView.bounds];

	[self.timeEntryPopupEditView addSubview:self.timeEntryEditViewController.view];
	[self.timeEntryEditViewController.view setFrame:self.timeEntryPopupEditView.bounds];
	self.defaultPopupHeight = self.timeEntryPopupEditView.bounds.size.height;
	self.addedHeight = 0;
	self.minimumEditFormWidth = self.timeEntryPopupEditView.bounds.size.width;
	self.runningEdit = NO;
}

- (void)initNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayTimeEntryList:)
												 name:kDisplayTimeEntryList
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayTimeEntryEditor:)
												 name:kDisplayTimeEntryEditor
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayLogin:)
												 name:kDisplayLogin
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(closeEditPopup:)
												 name:kForceCloseEditPopover
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resizeEditPopupHeight:)
												 name:kResizeEditForm
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resizeEditPopupWidth:)
												 name:kResizeEditFormWidth
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resetEditPopover:)
												 name:NSPopoverDidCloseNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(closeEditPopup:)
												 name:kCommandStop
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resetEditPopoverSize:)
												 name:kResetEditPopoverSize
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(focusListing:)
												 name:kFocusListing
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(escapeListing:)
												 name:kEscapeListing
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(effectiveAppearanceChangedNotification)
												 name:NSNotification.EffectiveAppearanceChanged
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowSizeDidChange)
												 name:NSWindowDidResizeNotification
											   object:nil];
}

- (void)initCollectionView
{
	self.dataSource = [[TimeEntryDatasource alloc] initWithCollectionView:self.collectionView];

	// Drag and drop
	//    [self.collectionView setDraggingSourceOperationMask:NSDragOperationLink forLocal:NO];
	//    [self.collectionView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
	//    [self.collectionView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
}

- (void)setupEmptyLabel
{
	NSMutableParagraphStyle *paragrapStyle = NSMutableParagraphStyle.new;

	paragrapStyle.alignment = kCTTextAlignmentCenter;

	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@" reports"];

	[string setAttributes:
	 @{
		 NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
		 NSForegroundColorAttributeName:[NSColor alternateSelectedControlColor]
	 }
					range:NSMakeRange(0, [string length])];
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Welcome back! Your previous entries are available in the web under" attributes:
									   @{ NSParagraphStyleAttributeName:paragrapStyle }];
	[text appendAttributedString:string];
	[self.emptyLabel setAttributedStringValue:text];
	[self.emptyLabel setAlignment:NSCenterTextAlignment];
}

- (void)startDisplayTimeEntryList:(NSNotification *)notification
{
	[self displayTimeEntryList:notification.object];
}

- (void)displayTimeEntryList:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	NSLog(@"TimeEntryListViewController displayTimeEntryList, thread %@", [NSThread currentThread]);

	NSArray<TimeEntryViewItem *> *newTimeEntries = [cmd.timeEntries copy];

    // reload
	[self.dataSource process:newTimeEntries showLoadMore:cmd.show_load_more];

    // Handle Popover
	if (cmd.open)
	{
		if (self.timeEntrypopover.shown)
		{
			[self.timeEntrypopover closeWithFocusTimer:YES];
			[self setDefaultPopupSize];
		}
        // when timer not focused
		if ([self.timerEditViewController.autoCompleteInput currentEditor] == nil)
		{
			[self focusListing:nil];
		}
	}

    // Show Empty view if need
	BOOL noItems = newTimeEntries.count == 0;
	[self.emptyLabel setEnabled:noItems];
	[self.timeEntryListScrollView setHidden:noItems];
}

- (void)resetEditPopover:(NSNotification *)notification
{
	if (notification.object == self.timeEntrypopover)
	{
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kResetEditPopover
																	object:nil];
	}
}

- (void)popoverWillClose:(NSNotification *)notification
{
	NSLog(@"%@", notification.userInfo);
}

- (void)displayTimeEntryEditor:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	NSLog(@"TimeEntryListViewController displayTimeEntryEditor, thread %@", [NSThread currentThread]);

    // Get selected index
	NSIndexPath *selectedIndexpath = [self.collectionView.selectionIndexPaths.allObjects firstObject];
	if (selectedIndexpath == nil)
	{
		return;
	}

	if (cmd.open)
	{
		self.timeEntrypopover.contentViewController = self.timeEntrypopoverViewController;
		self.runningEdit = (cmd.timeEntry.duration_in_seconds < 0);

		NSView *ofView = self.view;
		CGRect positionRect = [self positionRectOfSelectedRowAtIndexPath:selectedIndexpath];

		if (self.runningEdit)
		{
			ofView = self.headerView;
			positionRect = [ofView bounds];
			self.lastSelectedGUID = nil;
		}
		else if (self.selectedEntryCell && [self.selectedEntryCell isKindOfClass:[TimeEntryCell class]])
		{
			self.lastSelectedGUID = ((TimeEntryCell *)self.selectedEntryCell).GUID;
			ofView = self.collectionView;
		}

        // Show popover
		[self.timeEntrypopover showRelativeToRect:positionRect
										   ofView:ofView
									preferredEdge:NSMaxXEdge];

		BOOL onLeft = (self.view.window.frame.origin.x > self.timeEntryPopupEditView.window.frame.origin.x);
		[self.timeEntryEditViewController setDragHandle:onLeft];
	}
}

- (CGRect)positionRectOfSelectedRowAtIndexPath:(NSIndexPath *)indexPath {
	TimeEntryCell *selectedCell = [self getSelectedEntryCellWithIndexPath:indexPath];
	NSRect positionRect = self.view.bounds;

	if (selectedCell)
	{
		positionRect = [self.collectionView convertRect:selectedCell.view.bounds
											   fromView:selectedCell.view];
	}
	return positionRect;
}

- (void)startDisplayTimeEntryEditor:(NSNotification *)notification
{
	[self displayTimeEntryEditor:notification.object];
}

- (BOOL)  tableView:(NSTableView *)aTableView
	shouldSelectRow:(NSInteger)rowIndex
{
	[self clearLastSelectedEntry];
	return YES;
}

- (TimeEntryCell *)getSelectedEntryCellWithIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section < 0 ||  indexPath.section >= self.collectionView.numberOfSections)
	{
		return nil;
	}

	self.selectedEntryCell = nil;

	id item = [self.collectionView itemAtIndexPath:indexPath];
	if ([item isKindOfClass:[TimeEntryCell class]])
	{
		self.selectedEntryCell = (TimeEntryCell *)item;
		return self.selectedEntryCell;
	}
	return nil;
}

- (void)clearLastSelectedEntry
{
	[self.selectedEntryCell setupGroupMode];
}

- (void)resetEditPopoverSize:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kResetEditPopover
																object:nil];
	[self setDefaultPopupSize];
}

- (void)resizing:(NSSize)n
{
	[self.timeEntrypopover setContentSize:n];
	NSRect f = [self.timeEntryEditViewController.view frame];
	NSRect r = NSMakeRect(f.origin.x,
						  f.origin.y,
						  n.width,
						  n.height);

	[self.timeEntryPopupEditView setBounds:r];
	[self.timeEntryEditViewController.view setFrame:self.timeEntryPopupEditView.bounds];
}

- (void)resizeEditPopupHeight:(NSNotification *)notification
{
	if (!self.timeEntrypopover.shown)
	{
		return;
	}
	NSInteger addHeight = [[[notification userInfo] valueForKey:@"height"] intValue];
	if (addHeight == self.addedHeight)
	{
		return;
	}
	self.addedHeight = addHeight;
	float newHeight = self.timeEntrypopover.contentSize.height + self.addedHeight;
	NSSize n = NSMakeSize(self.timeEntrypopover.contentSize.width, newHeight);

	[self resizing:n];
}

- (void)resizeEditPopupWidth:(NSNotification *)notification
{
	if (!self.timeEntrypopover.shown)
	{
		return;
	}
	int i = [[[notification userInfo] valueForKey:@"width"] intValue];
	float newWidth = self.timeEntrypopover.contentSize.width + i;

	if (newWidth < self.minimumEditFormWidth)
	{
		return;
	}
	NSSize n = NSMakeSize(newWidth, self.timeEntrypopover.contentSize.height);

	[self resizing:n];
}

- (void)closeEditPopup:(NSNotification *)notification
{
	if (self.timeEntrypopover.shown)
	{
		if ([self.timeEntryEditViewController autcompleteFocused])
		{
			return;
		}
		if (self.runningEdit)
		{
			[self.timeEntryEditViewController closeEdit];
			self.runningEdit = false;
		}
		else
		{
			[self.selectedEntryCell openEdit];
		}

		[self setDefaultPopupSize];
	}
}

- (void)setDefaultPopupSize
{
	if (self.addedHeight != 0)
	{
		NSSize n = NSMakeSize(self.timeEntrypopover.contentSize.width, self.defaultPopupHeight);

		[self resizing:n];
		self.addedHeight = 0;
	}
}

- (void)startDisplayLogin:(NSNotification *)notification
{
	[self displayLogin:notification.object];
}

- (void)displayLogin:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	if (cmd.open && self.timeEntrypopover.shown)
	{
		[self.timeEntrypopover closeWithFocusTimer:YES];
		[self setDefaultPopupSize];
	}
}

- (void)textFieldClicked:(id)sender
{
	if (sender == self.emptyLabel && [self.emptyLabel isEnabled])
	{
		toggl_open_in_browser(ctx);
	}
}

- (void)focusListing:(NSNotification *)notification
{
	if (self.collectionView.numberOfSections == 0)
	{
		return;
	}

	NSIndexPath *selectedIndexpath = [self.collectionView.selectionIndexPaths.allObjects firstObject];
    // If list is focused with keyboard shortcut
	if (notification != nil && !self.timeEntrypopover.shown)
	{
		[self clearLastSelectedEntry];
		selectedIndexpath = [NSIndexPath indexPathForItem:0 inSection:0];
	}

	if (selectedIndexpath == nil)
	{
		return;
	}

	[[self.collectionView window] makeFirstResponder:self.collectionView];
	[self.collectionView selectItemsAtIndexPaths:[NSSet setWithObject:selectedIndexpath] scrollPosition:NSCollectionViewScrollPositionTop];

	TimeEntryCell *cell = [self getSelectedEntryCellWithIndexPath:selectedIndexpath];
	if (cell != nil)
	{
		[self clearLastSelectedEntry];
		[cell setFocused];
	}
}

- (void)escapeListing:(NSNotification *)notification
{
	if (self.timeEntrypopover.shown)
	{
		[self closeEditPopup:nil];
		return;
	}
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kFocusTimer
																object:nil];
	[self clearLastSelectedEntry];
	[self.collectionView deselectAll:nil];
	self.selectedEntryCell = nil;
}

#pragma mark Drag & Drop Delegates

- (BOOL)       tableView:(NSTableView *)aTableView
	writeRowsWithIndexes:(NSIndexSet *)rowIndexes
			toPasteboard:(NSPasteboard *)pboard
{
	if (aTableView == self.collectionView)
	{
        // Disable drag and drop for load more and group row
		TimeEntryViewItem *model = [self.viewitems objectAtIndex:[rowIndexes firstIndex]];
		if ([model loadMore] || model.Group)
		{
			return NO;
		}
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
		[pboard setData:data forType:NSStringPboardType];
		return YES;
	}
	else
	{
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView *)tv
				validateDrop:(id )info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
	return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tv
	   acceptDrop:(id )info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)op
{
	NSPasteboard *pboard = [info draggingPasteboard];
	NSData *rowData = [pboard dataForType:NSStringPboardType];
	NSIndexSet *rowIndexes =
		[NSKeyedUnarchiver unarchiveObjectWithData:rowData];
	NSInteger dragRow = [rowIndexes firstIndex];
	int dateIndex = (int)row - 1;

	if (([info draggingSource] == self.collectionView) & (tv == self.collectionView) && row != dragRow)
	{
		if (row == 0)
		{
			dateIndex = (int)row + 1;
		}

        // Updating the dropped item date
		TimeEntryViewItem *dateModel = [self.viewitems objectAtIndex:dateIndex];
		TimeEntryViewItem *currentModel = [self.viewitems objectAtIndex:dragRow];

		if ([dateModel loadMore])
		{
			dateModel = [self.viewitems objectAtIndex:dateIndex - 1];
		}

		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:currentModel.started];
		NSInteger hours = [components hour];
		NSInteger minutes = [components minute];
		NSInteger seconds = [components second];

		unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
		NSDateComponents *comps = [calendar components:unitFlags fromDate:dateModel.started];
		comps.hour = hours;
		comps.minute = minutes;
		comps.second = seconds;
		NSDate *newDate = [calendar dateFromComponents:comps];

		toggl_set_time_entry_date(ctx,
								  [currentModel.GUID UTF8String],
								  [newDate timeIntervalSince1970]);
	}
	return YES;
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
//    TimeEntryCell *cellView = [self.collectionView viewAtColumn:0 row:rowIndexes.firstIndex makeIfNecessary:NO];
//
//    if (cellView)
//    {
//        [session enumerateDraggingItemsWithOptions:NSDraggingItemEnumerationConcurrent
//                                           forView:tableView
//                                           classes:[NSArray arrayWithObject:[NSPasteboardItem class]]
//                                     searchOptions:@{}
//                                        usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop)
//         {
//             // prepare context
//             NSGraphicsContext *theContext = [NSGraphicsContext currentContext];
//             [theContext saveGraphicsState];
//
//             // drag image needs to be larger than the content in order to encapsulate the drop shadow
//             CGFloat imageOffset = 5;
//
//             // supply a drag background image
//             NSSize contentSize = draggingItem.draggingFrame.size;
//             contentSize.height = 56;
//             NSSize imageSize = NSMakeSize(contentSize.width + imageOffset, contentSize.height + imageOffset);
//             NSImage *image = [[NSImage alloc] initWithSize:imageSize];
//             [image lockFocus];
//
//             // define a shadow
//             NSShadow *shadow = [NSShadow new];
//             shadow.shadowColor = [[NSColor lightGrayColor] colorWithAlphaComponent:0.2];
//             shadow.shadowOffset = NSMakeSize(imageOffset, -imageOffset);
//             shadow.shadowBlurRadius = 3;
//             [shadow set];
//
//             // define content frame
//             NSRect contentFrame = NSMakeRect(0, imageOffset, contentSize.width, contentSize.height);
//             NSBezierPath *contentPath = [NSBezierPath bezierPathWithRect:contentFrame];
//
//             // draw content border and shadow
//             [[[NSColor lightGrayColor] colorWithAlphaComponent:0.6] set];
//             [contentPath stroke];
//             [theContext restoreGraphicsState];
//
//             // fill content
//             [[NSColor whiteColor] set];
//             contentPath = [NSBezierPath bezierPathWithRect:NSInsetRect(contentFrame, 1, 1)];
//             [contentPath fill];
//
//             [image unlockFocus];
//
//             // update the dragging item frame to accomodate larger image
//             draggingItem.draggingFrame = NSMakeRect(draggingItem.draggingFrame.origin.x, draggingItem.draggingFrame.origin.y, imageSize.width, imageSize.height);
//
//             // define additional image component for drag
//             NSDraggingImageComponent *backgroundImageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:@"background"];
//             backgroundImageComponent.contents = image;
//             backgroundImageComponent.frame = NSMakeRect(0, 0, imageSize.width, imageSize.height);
//
//             // we can provide custom content by overridding NSTableViewCell -draggingImageComponents
//             // which defaults to only including the image and text fields
//             draggingItem.imageComponentsProvider = ^NSArray *(void) {
//                 NSMutableArray *components = [NSMutableArray arrayWithArray:@[backgroundImageComponent]];
//                 NSArray *cellViewComponents = cellView.draggingImageComponents;
//                 [cellViewComponents enumerateObjectsUsingBlock:^(NSDraggingImageComponent *component, NSUInteger idx, BOOL *stop) {
//                      component.frame = NSMakeRect(component.frame.origin.x, component.frame.origin.y + imageOffset, component.frame.size.width, component.frame.size.height);
//                  }];
//
//                 [components addObjectsFromArray:cellViewComponents];
//                 return components;
//             };
//         }];
//    }
}

- (void)effectiveAppearanceChangedNotification {
    // Re-draw hard-code color sheme for all cells in tableview
	[self.collectionView reloadData];
}

- (NSInteger)collectionView:(nonnull NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
	return 0;
}

- (nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {
	return nil;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath {
	return nil;
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
	return CGSizeMake(280.0, 36.0);
}

- (void)windowSizeDidChange {
	[self.collectionView.collectionViewLayout invalidateLayout];
}

@end
