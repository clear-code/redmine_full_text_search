function observeIncrementalSearch(input, onChange) {
  var $input = $(input);
  var previousValue = $input.val();
  $input.keyup(function() {
    var currentValue = $input.val();
    if (currentValue === previousValue) {
      return;
    }
    previousValue = currentValue;
    onChange($input, currentValue);
  });
  if (previousValue !== "") {
    onChange($input, previousValue);
  }
}
