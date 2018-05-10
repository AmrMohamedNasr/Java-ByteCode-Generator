#include "label.h"

label::label() {
  this->label_name = label::label_char + to_string(label::label_num);
  if (label_num == UINT_MAX) {
    label::label_char++;
  }
  label_num++;
}

string label::get_name() {
  return this->label_name;
}