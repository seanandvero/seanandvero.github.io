my %hash = ();

open (my $fh, "<", "wedding_final_shares.txt") or die "Cant open file";

while (my $line =<$fh>) 
{
  chomp($line);
  my($key, $link) = $line =~ /(.*?\.JPG)(.*$)/igs;

  $link = $link =~ s/www\.dropbox\.com/dl.dropboxusercontent.com/r;
  $hash{$key}{photo} = $link;

  print $hash{$key}{photo}
}

open (my $fh2, "<", "wedding_final_thumb_shares.txt") or die "Cant open file";

while (my $line =<$fh2>) 
{
  chomp($line);
  my($key, $link) = $line =~ /thumb (.*?\.JPG)(.*$)/igs;
  $link = $link =~ s/www\.dropbox\.com/dl.dropboxusercontent.com/r;
  $hash{$key}{thumb} = $link;

  print $hash{$key}{thumb}
}

open (my $of, '>', 'wedding_images.txt') or die 'Cannot open for writing';

foreach $key (keys %hash) 
{
  $val = $hash{$key}{photo};
  $val2 = $hash{$key}{thumb};
  print $of "$key $val $val2\n";
}
