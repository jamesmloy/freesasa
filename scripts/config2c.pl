use strict;

# Script to generate source code for a classifier based on a
# config-file. Useful for having default classifiers statically in
# memory.  It generates a constant classifier that should be placed in
# its own source-file. The classifier, defined at the bottom should be
# renamed to a unique name. (marked with a comment in the output)

# This interpreter has stricter requirements on the input format than
# the one in the C-code, since it is only for internal use. It also
# doesn't do any syntax checks, so it will only work on valid config
# files. 

my %types;
my %atoms;
my %classes;
my %residues;
my $n_classes = 0;
my $n_residues = 0;
my $atom_flag = 0;
my $type_flag = 0;

(scalar @ARGV == 1) or die "Provide prefix for variable names";
my $prefix = shift @ARGV;

while (<>) {
    next if (/^#/);
    $_ =~ s/^(.*)#.*/$1/; # strip comments
    next if (/^\s*$/);
    if (/^types:/) {
        $type_flag = 1;
        $atom_flag = 0;
        next;
    }
    if (/^atoms:/) {
        $type_flag = 0;
        $atom_flag = 1;
        next;
    }
    if ($type_flag) {
        my ($name,$radius,$class) = split /\s+/, $_;
        $types{$name}{radius} = $radius;
        $types{$name}{class} = $class;
        if (! exists $classes{$class}) {
            $classes{$class} = $n_classes;
            ++$n_classes;
        }
    }
    if ($atom_flag) {
        my ($res,$atom,$type) = split /\s+/, $_;
        $atoms{$res}{$atom} = $type;
        if (! exists $residues{$res}) {
            $residues{$res} = $n_residues;
            ++$n_residues;
        }
    }
}
my @res_array = sort keys %residues;
print "#include \"classifier.h\"\n\n";
print "/* Autogenerated code from the script config2c.pl */\n\n";
print "static const char *$prefix\_residue_name[] = {";
print "\"$_\", "foreach (@res_array);
print "};\n";
print "static const char *$prefix\_class_name[] = {";
# display classes in order of appearance (to assure they are mapped to indices)
print "\"$_\", "foreach (sort {$classes{$a} <=> $classes{$b}} keys %classes);
print "};\n\n";

foreach my $res (@res_array) {
    my @atom_names = keys %{$atoms{$res}};
    print "static const char *$prefix\_$res\_atom_name[] = {";
    print "\"$_\", " foreach (@atom_names);
    print "};\n";
    print "static double $prefix\_$res\_atom_radius[] = {";
    print $types{$atoms{$res}{$_}}{radius},", " foreach (@atom_names);
    print "};\n";
    print "static int $prefix\_$res\_atom_class[] = {";
    print $classes{$types{$atoms{$res}{$_}}{class}},", " foreach (@atom_names);
    print "};\n";
    print "static struct classifier_residue $prefix\_$res\_cfg = {\n";
    print "    .name = \"$res\", .n_atoms = ", scalar keys %{$atoms{$res}},",\n";
    print "    .atom_name = (char**) $prefix\_$res\_atom_name,\n";
    print "    .atom_radius = (double*) $prefix\_$res\_atom_radius,\n";
    print "    .atom_class = (int*) $prefix\_$res\_atom_class };\n\n"
}
print "static struct classifier_residue *$prefix\_residue_cfg[] = {\n    ";
foreach my $res (@res_array) {
    print "&$prefix\_$res\_cfg, ";
}
print "};\n\n";

print "static struct classifier_config $prefix\_auto_config = {\n";
print "    .n_residues = $n_residues, .n_classes = $n_classes,\n";
print "    .residue_name = (char**) $prefix\_residue_name,\n";
print "    .class_name = (char**) $prefix\_class_name,\n";
print "    .residue = (struct classifier_residue **) $prefix\_residue_cfg\n";
print "};\n\n";
print "static void $prefix\_dummy_free(void *arg) {}\n\n";
print "const freesasa_classifier freesasa_$prefix\_classifier = {\n";
print "    .config = &$prefix\_auto_config,\n";
print "    .n_classes = $n_classes,\n";
print "    .radius = freesasa_classifier_config_radius,\n";
print "    .sasa_class =freesasa_classifier_config_class,\n";
print "    .class2str = freesasa_classifier_config_class2str,\n";
print "    // Since this object is const, calling free should emit compiler warnings.\n";
print "    .free_config = $prefix\_dummy_free,\n";
print "};\n";
      
