package Log::Any::Adapter::Screen;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Log::Any;
use Log::Any::Adapter::Util qw(make_method);
use base qw(Log::Any::Adapter::Base);
use Term::ANSIColor;
use Time::HiRes qw(time);

my $Time0 = time();

my @logging_methods = Log::Any->logging_methods;
our %logging_levels;
for my $i (0..@logging_methods-1) {
    $logging_levels{$logging_methods[$i]} = $i;
}
# some common typos
$logging_levels{warn} = $logging_levels{warning};

sub _default_level {
    return $ENV{LOG_LEVEL}
        if $ENV{LOG_LEVEL} && $logging_levels{$ENV{LOG_LEVEL}};
    return 'trace' if $ENV{TRACE};
    return 'debug' if $ENV{DEBUG};
    return 'info'  if $ENV{VERBOSE};
    return 'error' if $ENV{QUIET};
    'warning';
}

sub init {
    my ($self) = @_;
    $self->{stderr}    //= 1;
    $self->{use_color} //= (-t STDOUT);
    $self->{colors}    //= {
        trace     => 'yellow',
        debug     => '',
        info      => 'green',
        notice    => 'green',
        warning   => 'bold blue',
        error     => 'magenta',
        critical  => 'red',
        alert     => 'red',
        emergency => 'red',
    };
    $self->{min_level} //= _default_level();
    $self->{formatter} //= sub {
        my ($self, $msg) = @_;
        my $env = $ENV{LOG_PREFIX} // '';
        if ($env eq 'elapsed') {
            my $time = time();
            $msg = sprintf("[%9.3fms] %s", ($time - $Time0)*1000, $msg);
        }
        $msg;
    };
    $self->{_fh} = $self->{stderr} ? \*STDERR : \*STDOUT;
}

sub hook_before_log {
    return;
    #my ($self, $msg) = @_;
}

sub hook_after_log {
    my ($self, $msg) = @_;
    print { $self->{_fh} } "\n" unless $msg =~ /\n\z/;
}

for my $method (Log::Any->logging_methods()) {
    make_method(
        $method,
        sub {
            my ($self, $msg) = @_;

            return if $logging_levels{$method} <
                $logging_levels{$self->{min_level}};

            $self->hook_before_log($msg);

            if ($self->{formatter}) {
                $msg = $self->{formatter}->($self, $msg);
            }

            if ($self->{use_color} && $self->{colors}{$method}) {
                $msg = Term::ANSIColor::colored($msg, $self->{colors}{$method});
            }

            print { $self->{_fh} } $msg;

            $self->hook_after_log($msg);
        }
    );
}

for my $method (Log::Any->detection_methods()) {
    my $level = $method; $level =~ s/^is_//;
    make_method(
        $method,
        sub {
            my $self = shift;
            $logging_levels{$level} >= $logging_levels{$self->{min_level}};
        }
    );
}

1;
# ABSTRACT: Send logs to screen, with colors and some other features

=for Pod::Coverage ^(init|hook_.+)$

=head1 SYNOPSIS

 use Log::Any::Adapter;
 Log::Any::Adapter->set('Screen',
     # min_level => 'debug', # default is 'warning'
     # colors    => { trace => 'bold yellow on_gray', ... }, # customize colors
     # use_color => 1, # force color even when not interactive
     # stderr    => 0, # print to STDOUT instead of the default STDERR
     # formatter => sub { "LOG: $_[1]" }, # default none
 );


=head1 DESCRIPTION

This Log::Any adapter prints log messages to screen (STDERR/STDOUT). The
messages are colored according to level (unless coloring is turned off). It has
a few other features: allow passing formatter, allow setting level from some
environment variables, add prefix/timestamps.

Parameters:

=over 4

=item * min_level => STRING

Set logging level. Default is warning. If LOG_LEVEL environment variable is set,
it will be used instead. If TRACE environment variable is set to true, level
will be set to 'trace'. If DEBUG environment variable is set to true, level will
be set to 'debug'. If VERBOSE environment variable is set to true, level will be
set to 'info'.If QUIET environment variable is set to true, level will be set to
'error'.

=item * use_color => BOOL

Whether to use color or not. Default is true only when running interactively (-t
STDOUT returns true).

=item * colors => HASH

Customize colors. Hash keys are the logging methods, hash values are colors
supported by L<Term::ANSIColor>.

The default colors are:

 method/level                 color
 ------------                 -----
 trace                        yellow
 debug                        (none, terminal default)
 info, notice                 green
 warning                      bold blue
 error                        magenta
 critical, alert, emergency   red

=item * stderr => BOOL

Whether to print to STDERR, default is true. If set to 0, will print to STDOUT
instead.

=item * formatter => CODEREF

Allow formatting message. If defined, message will be passed before being
colorized. Coderef will be passed:

 ($self, $message)

and is expected to return the formatted message.

The default formatter can optionally prefix the message with extra stuffs,
depending on the content of LOG_PREFIX environment variable, such as: elapsed
time (e.g. C<< [0.023ms] >>) if LOG_PREFIX is C<elapsed>.

NOTE: Log::Any 1.00+ now has a proxy object which allows
formatting/customization of message before it is sent to adapter(s), so
formatting does not have to be done on a per-adapter basis. As an alternative to
this attribute, you can also consider using the proxy object or the (upcoming?)
global proxy object.

=back


=head1 ENVIRONMENT

LOG_LEVEL, QUIET, VERBOSE, DEBUG, TRACE. These environment variables can set the
default for C<min_level>. See documentation about C<min_level> for more details.

LOG_PREFIX. The default formatter groks these variables. See documentation about
C<formatter> about more details.


=head1 SEE ALSO

Originally inspired by L<Log::Log4perl::Appender::ScreenColoredLevel>. The old
name for this adapter is Log::Any::Adapter::ScreenColoredLevel but at some point
I figure using a shorter name is better for my fingers.

L<Log::Any>

L<Log::Log4perl::Appender::ScreenColoredLevel>

L<Term::ANSIColor>