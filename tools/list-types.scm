;; List all struct definitions
(type_definition
  type: (struct_specifier)
  declarator: (type_identifier) @name)

;; List all enum definitions
(type_definition
  type: (enum_specifier)
  declarator: (type_identifier) @name)
