//
//  OESaveStateController.m
//  OpenEmu
//
//  Created by Joshua Weinberg on 7/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "OESaveStateController.h"
#import "GameDocumentController.h"
#import "SaveState.h"

@implementation OESaveStateController


@synthesize plugins, availablePluginsPredicate, selectedPlugins, docController, 
selectedRomPredicate, browserZoom, sortDescriptors, pathArray, pathRanges;

- (id)init
{
    self = [super initWithWindowNibName:@"SaveStateManager"];
    if(self != nil)
    {
		self.docController = [GameDocumentController sharedDocumentController];
		self.selectedRomPredicate = nil;
		
		NSSortDescriptor *path = [[NSSortDescriptor alloc] initWithKey:@"rompath" ascending:NO];
		NSSortDescriptor *time = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:YES];
		
		self.sortDescriptors = [NSArray arrayWithObjects:path,time,nil];
		self.pathArray = [NSMutableArray array];
		self.pathRanges = [NSMutableArray array];
		
		[path release];
		[time release];
	}
    return self;
}

static void *ContentChangedContext = @"ContentChangedContext";

- (void)windowDidLoad
{
	NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES],NSRaisesForNotApplicableKeysBindingOption,nil];
	
//	NSLog(@"%d",[savestateController automaticallyRearrangesObjects]);
	//This keeps the outline view up to date
	[savestateController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:ContentChangedContext];

	[imageBrowser bind:@"content" toObject:savestateController withKeyPath:@"arrangedObjects" options:options];
	[imageBrowser bind:@"selectionIndexes" toObject:savestateController withKeyPath:@"selectionIndexes" options:options];
	[imageBrowser bind:@"zoomValue" toObject:self withKeyPath:@"browserZoom" options:options];
	
	[imageBrowser setCellsStyleMask:IKCellsStyleTitled];
	[imageBrowser setCellSize:NSMakeSize(150.0f, 150.0f)];
	[imageBrowser setAnimates:NO];
	
	[imageBrowser setDataSource:self];
	
	[holderView addSubview:listView];
	
	
	
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(doubleClickedOutlineView:)];
	listView.frame = holderView.bounds;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == ContentChangedContext)
	{
		[self updateRomGroups];
		[outlineView reloadData];
		[imageBrowser reloadData];
	}
}

- (void) doubleClickedOutlineView:(id) sender
{
//	NSLog(@"Clicked by: %@", sender);
	id selectedObject = [outlineView itemAtRow:[outlineView selectedRow]];
	
	if( [selectedObject class] == [SaveState class] )
		[self.docController loadState:[NSArray arrayWithObject:selectedObject]];
}

- (NSArray *)plugins
{
    return [[GameDocumentController sharedDocumentController] plugins];
}

- (void)dealloc
{
	self.docController = nil;
    [selectedPlugins release];
    [super dealloc];
}

- (void)setSelectedPlugins:(NSIndexSet *)indexes
{
    [selectedPlugins release];
    NSUInteger index = [indexes firstIndex];
    
    if(indexes != nil && index < [[pluginController arrangedObjects] count] && index != NSNotFound)
    {
        currentPlugin = [[pluginController selectedObjects] objectAtIndex:0];
        selectedPlugins = [[NSIndexSet alloc] initWithIndex:index];
		self.selectedRomPredicate = [NSPredicate predicateWithFormat:@"%K matches[c] %@",  @"emulatorID", [currentPlugin displayName] ];
    }
    else
    {
        selectedPlugins = [[NSIndexSet alloc] init];
        currentPlugin = nil;
    }
	[outlineView reloadData];
}

- (IBAction) toggleViewType:(id) sender
{
	[outlineView reloadData];
	NSSegmentedControl* segments = (NSSegmentedControl*) sender;

	switch( [segments selectedSegment] )
	{
		case 0:
			[collectionView removeFromSuperview];
			[holderView addSubview:listView];
			listView.frame = holderView.bounds;
			break;
		case 1:
			[listView removeFromSuperview];
			[holderView addSubview:collectionView];
			collectionView.frame = holderView.bounds;
			break;			
	}
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
	[self.docController loadState:[savestateController selectedObjects]];	
}

- (void) updateRomGroups
{
	NSArray *allItems = [savestateController arrangedObjects];
	
	[self.pathArray removeAllObjects];
	[self.pathRanges removeAllObjects];
	
	NSRange range;
	for( int i = 0; i < [allItems count]; i++ )
	{
		SaveState* state = [allItems objectAtIndex:i];
		
		if(! [self.pathArray containsObject:[state rompath]] )
		{
			if( [self.pathArray count] != 0 )
				[self.pathRanges addObject:[NSValue valueWithRange:range]];
			
			[self.pathArray addObject:[state rompath]];
			range.location = i;
			range.length = 1;
		}
		else
		{
			range.length++;
		}
		
	}
	if( [self.pathArray count] )
		[self.pathRanges addObject:[NSValue valueWithRange:range]];	
}
	
- (NSUInteger) numberOfGroupsInImageBrowser:(IKImageBrowserView *) aBrowser
{
	[self updateRomGroups];
	
	return [self.pathArray count];
}

- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index
{
	return [NSDictionary dictionaryWithObjectsAndKeys:[self.pathRanges objectAtIndex:index], IKImageBrowserGroupRangeKey,
			[[self.pathArray objectAtIndex:index] lastPathComponent] ,IKImageBrowserGroupTitleKey,
			[NSNumber numberWithInt:IKGroupDisclosureStyle], IKImageBrowserGroupStyleKey,
			nil];	
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if( item == nil ) //root
	{
		return [self.pathArray count];
	}
	else
	{
		return [[self.pathRanges objectAtIndex:[self.pathArray indexOfObject:item]] rangeValue].length;
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if( [self.pathArray containsObject:item] )
		return YES;
	return NO;
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if( item == nil )
	{
		return [self.pathArray objectAtIndex:index];
	}
	else
	{
		NSRange range = [[self.pathRanges objectAtIndex:[self.pathArray indexOfObject:item]] rangeValue];
		
		return [[savestateController arrangedObjects] objectAtIndex:range.location + index];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{ 
	if( [item class] == [SaveState class] )
	{
		return [item imageTitle];
	}
	return [[item description] lastPathComponent];
}




@end
