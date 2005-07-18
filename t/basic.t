use Test::More; 
#use Test::Deep;
use strict;
use vars qw($dsn $user $password);

if (defined $ENV{DBI_DSN}) {
  plan qw/no_plan/;
} else {
  plan skip_all => 'Need DBI_DSN connect string in environment to attempt testing.';
}   

BEGIN { use_ok('DBIx::AsForm') }

use DBI;
my $DBH =  DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS});
ok($DBH,'connecting to database'), 

# create test table
my $drv = $DBH->{Driver}->{Name};

ok(open(IN, "<t/create_test_table.".$drv.".sql"), 'opening SQL create file');
my $sql = join "", (<IN>);
my $created_test_table = $DBH->do($sql);
ok($created_test_table, 'creating test table');

my $daf = DBIx::AsForm->new($DBH);
ok($daf, "initial object creation");

# ###
# _decide_col_details
# ###

{ 
   my  ($input_type, $attr_href ) = $daf->_decide_col_details({ COLUMN_SIZE => 10 });
   is($input_type,'input', "expected input type for 10 (text box)");
   is($attr_href->{'size'}, 12 , "expected size for 10");
   is($attr_href->{maxlength}, 10 , "expected maxlength type for 10");
}
{ 
   my  ($input_type, $attr_href ) = $daf->_decide_col_details({ COLUMN_SIZE => 22 });
   is($input_type,'textarea', "expected tag type for 22 (textarea)");
   is($attr_href->{'size'}, undef , "expected size for 22");
   is($attr_href->{maxlength}, undef , "expected maxlength type for 22");
   is($attr_href->{rows}, 2 , "expected rows for 22");
   is($attr_href->{cols}, 20 , "expected cols type for 22");
}
{ 
   my  ($input_type, $attr_href ) = $daf->_decide_col_details({ TYPE_NAME => 'boolean',  });
   is($input_type,'select', "expected tag type SELECT for boolean");
   is($attr_href->{'size'}, undef , "expected size for boolean");
   is($attr_href->{maxlength}, undef , "expected maxlength type for boolean");
   is($attr_href->{rows}, undef , "expected rows for boolean");
   is($attr_href->{cols}, undef , "expected cols type for boolean");
}




my @html_form;
eval {
	@html_form = $daf->to_html_array('dbix_asform_test'); 
};
is($@,'', "eval'ing to_html_array");

my $html_href;
eval {
	$html_href = $daf->to_html_href('dbix_asform_test'); 
};
is($@,'', "eval'ing to_html_href");
ok( (ref $html_href eq 'HASH'), "to_html_href returns a hashref");

#  use Data::Dumper;
#  warn Dumper ($html_href);

{ 
    is($html_href->{'varchar_col'}->attr('size'),'4', "varchar sets expected size");
    is($html_href->{'varchar_col'}->attr('maxlength'),'2', "varchar sets expected maxlength");
#   use Data::Dumper;
#   warn Dumper ($html_href->{'varchar_col'}->as_HTML);
}


# For personal reality checking. 
# open (FILE, ">/home/mark/www/perl/dbix_asform.html") || die "can't write to file: $!";
# 
#     use CGI;
#     my $q = CGI->new();
#     print FILE $q->start_html().$q->start_form;
#         for my $href (@html_form) {
#             print FILE "<b>$href->{name}</b>: ". $href->{obj}->as_HTML." <br>"
#         }
#     print FILE $q->end_form.$q->end_html();
# close(FILE);

# We use an end block to clean up even if the script dies.
END {
 	if ($DBH) {
 		if ($created_test_table) {
 			$DBH->do("DROP TABLE dbix_asform_test");
 		}
 		$DBH->disconnect;
 	}
 };
