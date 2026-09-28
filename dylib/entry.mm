// Constructor runs at dylib load, before UIKit is up.
// Kick the real init onto the main queue so it fires after the run loop
// is live and views can be presented.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "executor.h"
#include "ui/overlay.h"

__attribute__((constructor))
static void cobble_init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        executor::Initialize();

        CobbleOverlay* ui = [CobbleOverlay shared];
        ui.onRun = ^(NSString* script) {
            executor::RunScriptAsync(
                std::string([script UTF8String]),
                ^(std::string result) {
                    NSString* s = [NSString stringWithUTF8String:result.c_str()];
                    [[CobbleOverlay shared] appendOutput:s ?: @"(binary output)"];
                });
        };
        [ui present];
    });
}
