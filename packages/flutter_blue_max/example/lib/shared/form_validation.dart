import 'package:reactive_forms/reactive_forms.dart';

/// Text remains in the form model while the user types incomplete numbers.
extension FormText on FormControl<String> {
  String get text => value ?? '';
  set text(String text) => updateValue(text);
  void clear() => updateValue('');
}

/// A model-level validation message shared by the example's text inputs.
void setInputError(AbstractControl<dynamic> control, String? message) {
  if (message == null) {
    control.removeError('input');
    return;
  }
  control.setErrors({'input': message}, markAsDirty: false);
}

const inputValidationMessages = <String, ValidationMessageFunction>{'input': _inputValidationMessage};

String _inputValidationMessage(Object error) => error as String;
