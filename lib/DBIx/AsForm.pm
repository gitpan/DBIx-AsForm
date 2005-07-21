package DBIx::AsForm;

use HTML::Element;
use Params::Validate (qw/:all/);
use warnings;
use strict;

=head1 NAME

DBIx::AsForm - Generate an HTML form from a database table. 

=cut

use vars qw/$VERSION/;
$VERSION = '0.02_01';

=head1 SYNOPSIS

Generate an HTML form a database table in a flexible way. 

Setup:


    use DBIx::AsForm;
    my $daf = DBIx::AsForm->new($dbh);

Generate an empty form:

    my @html_form = $daf->to_html_array('widgets');

    use CGI;
    my $q = CGI->new();
    print $q->start_form;
        for my $href (@html_form) {
            print "<b>$href->{name}</b>: ". $href->{obj}->as_HTML." <br>"
        }
    print $q->end_form;

=head1 MOTIVATION

This project was borne out of combined excitement and frustration with
L<Class::DBI::AsForm>. I like the general design of the module because it
doesn't try to do too much. However, I don't use L<Class::DBI> as part of my
standard development, and I didn't want to depend on C<Class::DBI> for this tool.

I also wanted smarter form element generation than L<Class::DBI::AsForm>
provides.  Over time I expect L<Class::DBI::AsForm> to improve in this area to
match the advances I've made in that area. 
   
=head1 METHODS

=head2 new()

  my $daf = DBIx::AsForm->new($dbh);

Creates a new DBIx::AsForm object. The first argument must be an existing
database handle. 

=cut 

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my ($dbh)  = validate_pos( @_, 1 );


    my $self = { dbh => $dbh };
	bless ($self, $class);
	return $self;
}


=head2 to_html_array()

   # simple syntax 
   my @html_form = $daf->to_html_array($table_name);

   # More flexible
   my @html_form = $daf->to_html_array(
    table     => $table, 
    row_href  => \%row,          # optional
    columns   => \@column_names, # optional, defaults to all
    stringify => {               # optional
        widget.id => 'widget_name'
    },
   );

This returns an array of hashrefs mapping all the column names of the table  to
HTML::Element objects representing form widgets.

An array is used to preserve the proper ordering.

Optionally, a hashref of data an be passed in to populate the form elements. 

A list of column names to use can be provided. The default is to use all
of them in the order DBI returns them.

Finally, 'stringify'. We will detect all the "has a" foreign key relationships
automatically. However, usually these are ID columns when we want to display a
name. Use C<stringify> to define another column name from the other table to display
in place of the ID. By default we will just display the ID. A future version will
support a callback here to define more complex stringification possibilities. 

=cut

sub to_html_array {
	my $self = shift;
    my %p;
    if (scalar @_ == 1) { 
        $p{table} = shift;
    }
    else {
        %p = validate( @_, {
                table     => 1,
                row_href  => { type => HASHREF, default => {}, },
                stringify => { type => HASHREF, default => {},  },
                columns   => { type => ARRAYREF, default => [], },
            });
    }

    my @col_meta;
    # get the details for specific rows
    if ((defined $p{columns}) and (scalar @{ $p{columns} })) {
        for my $col (@{ $p{columns} }) {
            # parameters are: $catalog, $schema, $table, $column
            my $sth = $self->{dbh}->column_info( undef, undef , $p{table}, $col ) || die "column_info didn't work";
            my %meta = %{ $sth->fetchrow_hashref };
            push @col_meta, \%meta;
        }
    }
    # get details for every row in the table.
    else {
        my $sth = $self->{dbh}->column_info( undef, undef , $p{table}, undef ) || die "column_info didn't work";
        @col_meta = @{ $sth->fetchall_arrayref({})  };

    }

    # Find has_a relationships, but skip the grunt work if none are found
    my %fk_meta;
    if (my $sth = $self->{dbh}->foreign_key_info( undef,undef,undef,undef,undef, $p{table})) {
        for my $fk (grep { defined $_->{'FK_COLUMN_NAME'} } @{ $sth->fetchall_arrayref({})  }) {
            # I don't know why DBI uses the "UK_" prefix here, but I stick with it. 
            my $uk_tbl = $fk->{'UK_TABLE_NAME'};
            my $uk_col = $fk->{'UK_COLUMN_NAME'};
            #  Change the column name if stringify says so
            $uk_col = $p{stringify}{"$uk_tbl.$uk_col"} if defined $p{stringify}{"$uk_tbl.$uk_col"};
            $fk_meta{ $fk->{'FK_COLUMN_NAME'} } = [ $uk_tbl, $uk_col ];
        }
    }

    for (@col_meta) {
        $_->{value} = $p{row_href}{ $_->{COLUMN_NAME} } if defined $p{row_href}{ $_->{COLUMN_NAME } };
        $_->{fk} = $fk_meta{ $_->{COLUMN_NAME} } if defined $fk_meta{ $_->{COLUMN_NAME} };
    }

    return map { $self->_to_field($_) } @col_meta;
}

=head2 to_html_href()

The same as C<to_html_array()>, but returns the results in a single hashref.

=cut

sub to_html_href {
    my @html_form = to_html_array(@_);
    return { map { $_->{name} => $_->{obj} } @html_form };
}


=head2 INTERNALS 

The details are subject to change without notice and are documented
here solely for the benefit of contributors to this module.  

=cut 

=head2 _to_field($column_info_row_href)

  my $href = _to_field($column_info_row_href);
  
  # Example contents of $href
  { name => 'widget', obj => $a };

This maps an individual column to a form element. The input is expected
to be a hashref as would be returned in as an array element from a call
to DBI's C<column_info()>.

The output is a hashref with 'name' and 'obj' keys to hold the column name and
a HTML::Element object. 

=cut

sub _to_field {
    my $self = shift;
    my $col_meta = shift;

    my ($type,$attr) = $self->_decide_col_details($col_meta);

    my $type_meth = '_to_'.$type;
    return {
        name => $col_meta->{COLUMN_NAME},
        obj  => $self->$type_meth($col_meta, { %$attr, name=> $col_meta->{COLUMN_NAME} }),   
    };
}

sub _to_textarea {
	my ($self, $col, $attr) = @_;
	my $a = HTML::Element->new("textarea", %$attr);
    $a->push_content($attr->{value});
	return $a;
}

sub _to_input {
	my ($self, $col,$attr) = @_;
	my $a = HTML::Element->new("input", %$attr);
	$a->attr("value" => $attr->{value}) if defined $attr->{value};
	return $a;
}

sub _to_select {
	my ($self, $col, $attr) = @_;

    my $a;

    my ($tbl,$other_col_name) = @{ $col->{fk} } if (ref $col->{fk} eq 'ARRAY');
    if (defined $other_col_name) {
        $a           = HTML::Element->new("select", %$attr);

        my $other_col_vals_aref = $self->{dbh}->selectcol_arrayref(
            "SELECT $other_col_name FROM $tbl") || [];

        for (@{ $other_col_vals_aref }) {
            my $sel = HTML::Element->new("option", value => $_);
            $sel->attr("selected" => "selected") if (defined $col->{value} && $_ eq $col->{value});
            $sel->push_content( $_ );
            $a->push_content($sel);
        }
    }
    elsif ($col->{TYPE_NAME} =~ /bool/i) {
        $a   = HTML::Element->new("select", %$attr);
        my %bool = (
            1 => 'Yes',
            0 => 'No',
        );
        for (0,1) {
            my $sel = HTML::Element->new("option", value => $_);
            $sel->attr("selected" => "selected") if (defined $col->{value} && $_ eq $col->{value});
            $sel->push_content( $bool{$_} );
            $a->push_content($sel);
        }
    }
    else {
     die "couldn't figure out how to build select tag."
    }
	return $a;
}

=head3 _decide_col_details()

  ($input_type, $attr_href ) = $self->_decide_col_details($row_href);

Returns a suggested HTML form element type and an attribute of form tag attributes
based on a hashref of column meta data, as supplied by DBI's column_info().

=cut

sub _decide_col_details {
    my $self = shift;

    # As returned from DBI's column_info
    my $col_meta = shift;

    # use Data::Dumper;
    # warn Dumper ($col_meta) ;
    # # if ($col_meta->{COLUMN_NAME} eq 'textarea');

    my ($input_type,%attr);
    my $default_field_size = 20;

    my $type = $col_meta->{TYPE_NAME};
    if (defined $col_meta->{fk} || (defined $type && ($type =~ /bool/i)) ) {
        $input_type = 'select';
    }
    # Should I be checking for DATA_TYPE = 12 here to be more reliable and portable?
    elsif ((defined $type) && ($type eq 'text')) {
        $input_type = 'textarea';
        $attr{cols} = $default_field_size;
        $attr{rows} = 4 # arbitrary;

    }
    # We'll leave the maxlength and size alone for integers
    elsif ((defined $type) && ($type =~ m/^(big|small)?int(eger)?$/i)) {
        $input_type = 'input';
        $attr{'type'} = 'text'; 
        $attr{'size'} = $default_field_size;
    }
    # a text field
    else {
        my $col_size = $col_meta->{COLUMN_SIZE};
        $col_size = $default_field_size unless defined $col_size;

        # shrink the form of the field size is smaller than our default
        my $size = $col_size if ($col_size < $default_field_size);
        
        # make cells slightly larger than the data in them.
        # this is needed to make it look "right" in some browsers.
        if ($col_size <= $default_field_size) {
            $size = $col_size+2;
            $input_type = 'input';
            $attr{'type'} = 'text'; 
            $attr{'size'} = $size;
            $attr{'maxlength'} = $col_size;
        }
        # if it's larger than the default, turn it into a textarea
        # this prevents things like varchar(4000) from looking crazy.
        # the textarea is specially sized to fit the length of the field
        else {
            $input_type = 'textarea';
            $attr{cols} = $default_field_size;
            $attr{rows} = int $col_size/$default_field_size +1;
        }
    }

    # we have now calculated these new values:
    return ($input_type, \%attr); 
}
    
1;

=head1 SEE ALSO

L<Class::DBI::AsForm> - The same idea, integrated with L<Class::DBI>

L<HTML::FormEngine::DBSQL> - It has similiar functionality, but is difficult to
use and customize if you don't want the other functionality. 

B<DB_Browser> - http://www.summersault.com/sofware/db_browser - The oldest automated
database to form tool I'm aware of. The code looks old school now, but still has some 
useful nuggest of wisdom about database meta data. 

=head1 TODO

 * Testing generally isn't done
 * Foreign key stuff is broken
 * Test with more databases besides PostgreSQL
 * Set a max size limit on the textareas
 * Consider smarter date fields types, perhaps integrate
   with one of the JavaScript calendar date-picker things.
 * Possible tab-completion for has-a relationships with big
   tables (via AJAX). 
 * Address underlying issue that HTML::Element doesn't always produce
   valid HTML/XHTML

=head1 BUGS

please report any bugs or feature requests to
c<bug-dbix-asform@rt.cpan.org>, or through the web interface at
l<http://rt.cpan.org/noauth/reportbug.html?queue=dbix-asform>.
i will be notified, and then you'll automatically be notified of progress on
your bug as i make changes.

=head1 CONTRIBUTING

Patches, questions and feedback are welcome. This project is managed using
the darcs source control system ( http://www.darcs.net/ ). My darcs archive is here:
http://mark.stosberg.com/darcs_hive/as_form/

=head1 AUTHOR

Mark Stosberg, c<< <mark@summersault.com> >>

=head1 Acknowledgements

=head1 Copyright & License

copyright 2005 Mark Stosberg, all rights reserved.

this program is free software; you can redistribute it and/or modify it
under the same terms as perl itself.

=cut

1; 
