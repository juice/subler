//
//  SBLogger.m
//  Subler
//

#import "SBApplication.h"
#import "SBExceptionAlertController.h"

@implementation SBApplication

static void CrashMyApplication()
{
    *(char *)0x08 = 1;
}

- (NSAttributedString *)_formattedExceptionBacktrace:(NSArray *)backtrace
{
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    for (NSString *s in backtrace)
    {
        s = [s stringByAppendingString:@"\n"];
        NSAttributedString *attrS = [[NSAttributedString alloc] initWithString:s];
        [result appendAttributedString:attrS];
        [attrS release];
    }
    [result addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Monaco" size:10] range:NSMakeRange(0, result.length)];
    return [result autorelease];
}

- (void)reportException:(NSException *)exception
{
    // NSApplication simply logs the exception to the console. We want to let the user know
    // when it happens in order to possibly prevent subsequent random crashes that are difficult to debug
    @try
    {
        @autoreleasepool
        {
            // Create a string based on the exception
            NSString *exceptionMessage = [NSString stringWithFormat:@"%@\nReason: %@\nUser Info: %@", exception.name, exception.reason, exception.userInfo];
            
            SBExceptionAlertController *alertController = [[SBExceptionAlertController alloc] init];
            alertController.exceptionMessage = exceptionMessage;
            alertController.exceptionBacktrace = [self _formattedExceptionBacktrace:exception.callStackSymbols];

            NSInteger result = [alertController runModal];
            if (result == SBExceptionAlertControllerResultCrash)
            {
                CrashMyApplication();
            }
        }
    }
    @catch (NSException *e)
    {
        // Suppress any exceptions raised in the handling
    }    
}

@end
