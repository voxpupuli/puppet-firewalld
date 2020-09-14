# @summary Returns a string that is safe for firewalld filenames
#
# @example Regular Filename
#   $filename = 'B@d Characters!'
#   firewalld::safe_filename($orig_string)
#
#   Result => 'B_d_Characters_'
#
# @example Filename with Options
#   $filename = 'B@d Characters!.txt'
#   firewalld::safe_filename(
#     $filename,
#     {
#       'replacement_string' => '--',
#       'file_extension'     => '.txt'
#     }
#   )
#
#   Result => 'B--d--Characters--.txt'
#
# @param filename
#   The String to process
#
# @param options
#   Various processing options
#
# @param options [String[1]] replacement_string
#   The String to use when replacing invalid characters
#
# @option options [String[1]] file_extension
#   This will be stripped from the end of the string prior to processing and
#   re-added afterwards
#
# @return [String]
#   Processed string
#
function firewalld::safe_filename(
  String[1] $filename,
  Struct[
    {
      'replacement_string' => Pattern[/^[\w-]+$/],
      'file_extension'     => Optional[String[1]]
    }
  ]         $options  = { 'replacement_string' => '_' }
) {
  $_badchar_regex = '[^\w-]'

  # If we have an extension defined
  if $options['file_extension'] {
    # See if the string ends with the extension
    $_extension_length = length($options['file_extension'])
    if $filename[-($_extension_length), -1] == $options['file_extension'] {
      # And extract the base filename
      $_basename = $filename[0, -($_extension_length) - 1]
    }
  }

  # If we extraced a base filename substitute on that and re-add the file extension
  if defined('$_basename') {
    sprintf('%s%s',
      regsubst($_basename, $_badchar_regex, $options['replacement_string'], 'G'),
      $options['file_extension']
    )
  }
  # Otherwise, just substitute on the original filename
  else {
    regsubst($filename, $_badchar_regex, $options['replacement_string'], 'G')
  }
}
