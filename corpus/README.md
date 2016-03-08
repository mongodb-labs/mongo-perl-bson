# BSON Corpus

This BSON test data corpus consists of a JSON file for each BSON type, plus
a `top.json` file for testing the overall, enclosing document.

Top level keys include:

* `description`: human-readable description of what is in the file
* `bson_type`: hex string of the first byte of a BSON element (e.g. "0x01"
  for type "double"); this will be the synthetic value "0x00" for `top.json`.
* `valid` (optional): an array of valid test cases (see below).
* `decodeErrors` (optional): an array of decode error cases (see below).
* `parseErrors` (optional): an array of type-specific parse error case (see
  below).

Valid test case keys include:

* `description`: human-readable test case label.
* `subject`: a big-endian hex representation of a BSON string.
* `string`: a human-readable reprentation of an element under test.
* `decodeOnly` (optional): if true, indicates that the BSON can not roundtrip; decoding
  the BSON in 'subject' and re-encoding the result will not generate
  identical BSON; otherwise, encode(decode(subject)) should be the same as
  the subject.
* `extjson` (optional): a document representing a decoded extended JSON
  document equivalent to the subject.  If there is no extended JSON
  representation, this field will be omitted.

Decode error cases provide an invalid BSON document or field that
should result in an error. For each case, keys include:

* `description`: human-readable test case label.
* `subject`: a big-endian hex representation of an invalid BSON string that
  should fail to decode correctly.

Parse error cases are type-specific and represent some input that can not
be encoded to the `bson_type` under test.  For each case, keys include:

* `description`: human-readable test case label.
* `subject`: a text or numeric representation of an input that can't be
  encoded.

