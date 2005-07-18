
create TABLE dbix_asform_test (
	primary_id			int2 not null primary key
	, int4_not_null	    int4 not null
	, int8_col		    int8
	, float4_col		float4
	, float8_col		float8
	, text_col		    text
	, varchar_col		varchar(2)
	, char_col		    char(3)		
	, bool_col		    boolean not null default 't'
	, date_col		    date
	, timestamp_col     timestamp
	, time_col		    time		
	, pick_one		    varchar(10) CHECK(pick_one IN('duck','goose','caboose'))
    , varchar_500       varchar(500)
    , textarea          text
);
