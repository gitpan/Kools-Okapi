# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Kools::Okapi;

$loaded = 1;
print "\t\t\t\t\t\t";
print "ok 1\n";

######################### End of black magic.

my $fs = "\x1C";
my $gs = "\x1D";
my $rs = "\x1E";
my $us = "\x1F";

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

#$SIG{INT} = 'CleanShutDown';

my $retval;
my $icc;

sub CleanShutDown()
{
  $SIG{INT} = 'CleanShutDown';
  $shutdown = 1;
}

sub dataMsg_callBack($$$)
{
    print "In callBack  ";
    my $io=shift;
    my $key=shift;
    my $type=shift;
    print "  $io:$key:$type\n";
    
    SWITCH: # (type)
    {
        if (Kools::Okapi::ICC_DATA_MSG_SIGNON==$type) {
            print "Got a ICC_DATA_MSG_SIGNON\n";
            last SWITCH;
        }
        if (Kools::Okapi::ICC_DATA_MSG_SIGNOFF==$type) {
            print "Got a ICC_DATA_MSG_SIGNOFF\n";
            last SWITCH;
        }
        if (Kools::Okapi::ICC_DATA_MSG_RELOAD_END==$type) {
            print "Got a ICC_DATA_MSG_RELOAD_END\n";
            last SWITCH;
        }
        if (Kools::Okapi::ICC_DATA_MSG_REQUEST==$type) {
            print "Got a ICC_DATA_MSG_REQUEST\n";
            last SWITCH;
        }
        if (Kools::Okapi::ICC_DATA_MSG_TABLE==$type) {
            print "Got a ICC_DATA_MSG_TABLE\n";
            last SWITCH;
        }
        printf "Unknown message type: %d\n",type;
    }
    
    return Kools::Okapi::ICC_OK;
}

print "ICC_create:\n";
$icc = ICC_create(
                  Kools::Okapi::ICC_CLIENT_NAME,           'REUTERS',
                  Kools::Okapi::ICC_KIS_HOST_NAMES,        'localhost',
                  Kools::Okapi::ICC_PORT_NAME,             'tradekast',
                  
                  Kools::Okapi::ICC_CLIENT_RECEIVE_ARRAY,  [ "SpotDeals", "FxSwapDeals", "ForwardDeals", "NeverCheckUserCode" ],
                  Kools::Okapi::ICC_DATA_MSG_CALLBACK,    \&dataMsg_callBack);

print "ok 1\n";
ICC_set($icc,Kools::Okapi::ICC_CLIENT_READY, 1);
ICC_main_loop($icc);
print "ok 2\n";
ICC_main_loop($icc);
print "ok 3\n";

