package java::io::ObjectInputStream;

use warnings;
use strict;
use Method::Signatures::Simple;
use Data::Dumper;

use constant {
	STREAM_MAGIC      => 0xaced,              # short
	STREAM_VERSION    => 5,                   # short
	TC_NULL           => pack("C", 0x70),     # byte
	TC_REFERENCE      => pack("C", 0x71),     # byte
	TC_CLASSDESC      => pack("C", 0x72),     # byte
	TC_OBJECT         => pack("C", 0x73),     # byte
	TC_STRING         => pack("C", 0x74),     # byte
	TC_ARRAY          => pack("C", 0x75),     # byte
	TC_CLASS          => pack("C", 0x76),     # byte
	TC_BLOCKDATA      => pack("C", 0x77),     # byte
	TC_ENDBLOCKDATA   => pack("C", 0x78),     # byte
	TC_RESET          => pack("C", 0x79),     # byte
	TC_BLOCKDATALONG  => pack("C", 0x7A),     # byte
	TC_EXCEPTION      => pack("C", 0x7B),     # byte
	TC_LONGSTRING     => pack("C", 0x7C),     # byte
	TC_PROXYCLASSDESC => pack("C", 0x7D),     # byte
	TC_ENUM           => pack("C", 0x7E),     # byte
	baseWireHandle    => 0x7E,                # int

	SC_WRITE_METHOD   => pack("C", 0x01),
	SC_SERIALIZABLE   => pack("C", 0x02),
	SC_EXTERNALIZABLE => pack("C", 0x04),
	SC_BLOCK_DATA     => pack("C", 0x08),
	SC_ENUM           => pack("C", 0x10),

	PRIM_BYTE         => pack("C", 66), # 'B'
	PRIM_CHAR         => pack("C", 67), # 'C'
	PRIM_DOUBLE       => pack("C", 68), # 'D'
	PRIM_FLOAT        => pack("C", 70), # 'F'
	PRIM_INT          => pack("C", 73), # 'I'
	PRIM_LONG         => pack("C", 74), # 'J'
	PRIM_SHORT        => pack("C", 83), # 'S'
	PRIM_BOOL         => pack("C", 90), # 'Z'

	PRIM_ARRAY        => pack("C", 91), # '['
	PRIM_OBJECT       => pack("C", 76), # 'L'
};

our %descriptions = (
	TC_NULL           => 'TC_NULL',
	TC_REFERENCE      => 'TC_REFERENCE',
	TC_CLASSDESC      => 'TC_CLASSDESC',
	TC_OBJECT         => 'TC_OBJECT',
	TC_STRING         => 'TC_STRING',
	TC_ARRAY          => 'TC_ARRAY',
	TC_CLASS          => 'TC_CLASS',
	TC_BLOCKDATA      => 'TC_BLOCKDATA',
	TC_ENDBLOCKDATA   => 'TC_ENDBLOCKDATA',
	TC_RESET          => 'TC_RESET',
	TC_BLOCKDATALONG  => 'TC_BLOCKDATALONG',
	TC_EXCEPTION      => 'TC_EXCEPTION',
	TC_LONGSTRING     => 'TC_LONGSTRING',
	TC_PROXYCLASSDESC => 'TC_PROXYCLASSDESC',
	TC_ENUM           => 'TC_ENUM',
	baseWireHandle    => 'baseWireHandle',

	SC_WRITE_METHOD   => 'SC_WRITE_METHOD',
	SC_SERIALIZABLE   => 'SC_SERIALIZABLE',
	SC_EXTERNALIZABLE => 'SC_EXTERNALIZABLE',
	SC_BLOCK_DATA     => 'SC_BLOCK_DATA',
	SC_ENUM           => 'SC_ENUM',

	PRIM_BYTE         => 'PRIM_BYTE',
	PRIM_CHAR         => 'PRIM_CHAR',
	PRIM_DOUBLE       => 'PRIM_DOUBLE',
	PRIM_FLOAT        => 'PRIM_FLOAT',
	PRIM_INT          => 'PRIM_INT',
	PRIM_LONG         => 'PRIM_LONG',
	PRIM_SHORT        => 'PRIM_SHORT',
	PRIM_BOOL         => 'PRIM_BOOL',

	PRIM_ARRAY        => 'PRIM_ARRAY',
	PRIM_OBJECT       => 'PRIM_OBJECT',
);

# name => [ nr_of_bytes, how_to_unpack ]
our %primitives = (
	'byte'          => [1, 's'],
	'short'         => [2, 'n'],
	'unsignedshort' => [2, 'n'],
	'int'           => [4, 'N'],
	'float'         => [4, 'f'],
	'long'          => [8, 'q'],
	'uid'           => [8, 'H*'],
);
#	'double'        => [],
#	'bool'          => [],



method new($class: $fh) {
	my $self = bless( {
		fh       => $fh,
		ok       => 1,
		debug    => 1,
		debugprimitive => 1,
		depth    => 0,
		objects  => [],
	}, $class);

	my $magic = $self->readPrimitive('unsignedshort');
	my $stream_version = $self->readPrimitive('unsignedshort');
	warn "New stream, version: $stream_version\n" if $self->{debug};

	if ($magic ne STREAM_MAGIC) {
		$self->{ok} = 0;
		die("Bad Stream\n");
	}

	if ($stream_version ne STREAM_VERSION) {
		$self->{ok} = 0;
		die("Bad Stream Version\n");
	}

	return $self;
}

method enableDebug() {
	$self->{debug} = 1;
}

# Check if the stream is ok
method ok() {
	return $self->{ok};
}

method readPrimitive($type) {
	my $tmp;

	die "Unknown primitive $type" unless $primitives{$type};
	
	my $nr_of_bytes   = $primitives{$type}->[0];
	my $how_to_unpack = $primitives{$type}->[1];

	read($self->{fh}, $tmp, $nr_of_bytes);

	$self->debugStream($type, $tmp);

	return $tmp if $type eq 'byte';
	return unpack($how_to_unpack, $tmp);
}
	
method readString() {
	my $tmp;
	my $string_length = $self->readPrimitive('unsignedshort');
	read($self->{fh}, $tmp, $string_length);
	$self->debugStream('String', $tmp);
	return $tmp;
}

method readBlockData() {
	my $size = ord($self->readPrimitive('byte'));
	my $tmp;
	read($self->{fh}, $tmp, $size);
	$self->debugStream('BlockData', $tmp);

	my $end = $self->readPrimitive('byte');
	die ("Blockdata not properly closed") unless($end eq TC_ENDBLOCKDATA);

	return $tmp;
}

method info($txt) {
	warn " " x $self->{depth} . "$txt\n" if $self->{debug};
}

method debugStream($type, $data) {
	return unless $self->{debug};

	printf STDERR "%-40s", $type;
	for (my $i = 0; $i < length($data); ++$i) {
		printf STDERR (" %02x", ord(substr($data, $i, 1)));
	}

	print STDERR "\n";
}

method newHandle($object) {
	push(@{$self->{objects}}, $object);
	print STDERR "newHandle: ".(scalar(@{$self->{objects}}) - 1)."\n" if $self->{debug};
}

method readObject() {
	my $object = 0;
	++$self->{depth};
	$self->info("Object");

	my $objType = $self->readPrimitive('byte');

	if ($objType eq TC_NULL)         { $self->info('-Null');      $object = 0; }
	elsif ($objType eq TC_CLASSDESC) { $self->info('-ClassDesc'); $object = $self->readClassDesc; }
	elsif ($objType eq TC_REFERENCE) { $self->info('-Reference');
		my $s  = $self->readPrimitive('short');
		my $s2 = $self->readPrimitive('short');
		$object = @{$self->{objects}}[$s2];
		die("Illegal reference") if $s ne baseWireHandle;
		$self->info(":: $s2 ($object)");
	}
	elsif ($objType eq TC_OBJECT) { $self->info('-Object');
		my $class = $self->readObject;
		$object = $self->readClassData($class);
	}
	elsif ($objType eq TC_ARRAY) { $self->info('-Array');
		my $class = $self->readObject;
		$object = $self->readArray($class);
		$self->newHandle($object);
	}
	elsif ($objType eq TC_STRING) { $self->info('-String');
		$object = $self->readString;
		$self->info(":: $object");
		$self->newHandle($object);
	}
	elsif ($objType eq TC_BLOCKDATA) { $self->info('-BlockData');
		my $data = { blockdata => $self->readBlockData() };
		$self->newHandle($data);
	}
	elsif ($objType eq TC_RESET) { warn "Not implemented"; }
	else {
		#print Dumper($self->{objects});
		die("Illegal objecttype: ".ord($objType));
	}

	$self->info("/Object");
	--$self->{depth};

	return $object;
}

method readArray($class) {
	++$self->{depth};
	my $size = $self->readPrimitive('int');
	my $a = [];
	my $type = $class->{arrayType};
	$self->info("Array/$type [$size]");

	#   warn $size;
	#   warn Dumper($class);
	for (1..$size) {
		my $elem = $self->readType($type);
	#       warn Dumper($elem);
		push(@{$a}, $elem);
	}

	--$self->{depth};
	return $a;
}

method readType($type, $arrayType, $field) {
	if ($type eq PRIM_BYTE)   { return $self->readPrimitive('byte'); }
	if ($type eq PRIM_BOOL)   { return $self->readPrimitive('byte'); }
	if ($type eq PRIM_OBJECT) { return $self->readObject; }
	if ($type eq PRIM_ARRAY)  { return $self->readArray; } # readObject
	if ($type eq PRIM_FLOAT)  { return $self->readPrimitive('float'); }
	if ($type eq PRIM_INT)    { return $self->readPrimitive('int'); }
	if ($type eq PRIM_CHAR)   { warn "TODO"; }
	if ($type eq PRIM_DOUBLE) { warn "TODO"; }
	if ($type eq PRIM_LONG)   { warn "TODO"; }
	if ($type eq PRIM_SHORT)  { warn "TODO"; }

	warn Dumper($self);
	die("Illegal type");
}

method readObjectFields($class, $object) {
	++$self->{depth};
	$self->info("<ObjectFields>");
	++$self->{depth};

	foreach my $f (@{$class->{fields}}) {
		$self->info("=readType(".$f->{type}.")");
		my $v = $self->readType($f->{type});
		$self->info("=Field[".$f->{name}."]=$v (".$f->{type}.")");
		$object->{$f->{name}} = $v;
	}

	--$self->{depth};
	$self->info("</ObjectFields>");
	--$self->{depth};
}

method readClassAnnotation() {
	my $tmp = $self->readPrimitive('byte');
	$self->info("=classAnnotation ENDBLOCKDATA");
	die("Annotations unsupported") if $tmp ne TC_ENDBLOCKDATA;
}

method readFields($class) {
	my $fieldCount = $self->readPrimitive('short');

	++$self->{depth};
	$self->info("Fields[$fieldCount]");
	for (1..$fieldCount) {
		my $type = $self->readPrimitive('byte');
		my $name = $self->readString;

		my $field = {
			type => $type,
			name => $name,
		};

		$self->info("=Field/$type: $name");
		if ($type eq PRIM_OBJECT || $type eq PRIM_ARRAY) {
			$field->{subtype} = $self->readObject;
		}

		push(@{$class->{fields}}, $field);
	}
	--$self->{depth};
}

method readClassDesc() {
	++$self->{depth};

	my $name  = $self->readString;
	my $uid   = $self->readPrimitive('uid');
	my $flags = $self->readPrimitive('byte');

	my $class = {
		name      => $name,
		uid       => $uid,
		flags     => $flags,
		fields    => [],
		arrayType => substr($name, 1, 1),
	};

	my $txtflags = sprintf("%02x", ord($flags));
	$self->info("ClassDesc: $name/$uid/$txtflags");

	$self->newHandle($class);

	$self->readFields($class);
	$self->readClassAnnotation;

	$self->info("Super");
	++$self->{depth};
	$class->{super} = $self->readObject;
	--$self->{depth};

	$self->info("/ClassDesc: $name/$uid/$txtflags");
	--$self->{depth};
	return $class;
}

method readClassData($class, $object) {
	$object = {
		fields => {},
	} unless $object;
	++$self->{depth};

	$self->info("ClassData");

	# TODO: the spec says this can be an array
	$self->newHandle($object);

	if ($class->{super}) {
		# TODO: is this correct?
		$self->info("=Super");
		$object->{super} = $self->readClassData($class->{super});
	}

	#print Dumper($class);
	#$self->info("=ObjectFields");
	#for my $f (@{$class->{fields}}) {
	# my $v = $self->readType($f->{type});
	# $object->{fields}->{$f->{name}} = $v;
	# $self->info("=Field[".$f->{name}."]=$v (".$f->{type}.")");
	#}

	if ($class->{flags} | SC_SERIALIZABLE) {
		$self->readObjectFields($class, $object);
	}
	else {
		warn "TODO";
	}
	$self->info("/ClassData");
	--$self->{depth};
	return $object;
}

1;
