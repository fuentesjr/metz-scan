# frozen_string_literal: true

require_relative "../demeter_train_wreck" unless defined?(RuboCop::Cop::Metz::DemeterTrainWreck)

module RuboCop
  module Cop
    module Metz
      class DemeterTrainWreck
        # Static type-inference data for `Metz/DemeterTrainWreck`. Hosts the
        # `METHOD_RETURN_TYPES` map (per `docs/demeter-design.md` §5), the
        # AST-node-to-value-object literal map, the pass-through method set,
        # the operator method set, and the reverse-lookup table that powers
        # the unknown-receiver heuristic from §1 of the design doc.
        module TypeInference # rubocop:disable Metrics/ModuleLength
          PASS_THROUGH = %i[tap then yield_self itself dup clone freeze].to_set.freeze

          OPERATOR_METHODS = (
            %i[+ - * / % **] +
              %i[== != < > <= >= <=> === =~ !~] +
              %i[& | ^ << >>]
          ).to_set.freeze

          # rubocop:disable Lint/BooleanSymbol
          LITERAL_MAP = {
            str: :string, dstr: :string, xstr: :string,
            sym: :symbol, dsym: :symbol,
            int: :integer, float: :float,
            array: :array, hash: :hash,
            true: :boolean, false: :boolean, nil: :nil_value,
            regexp: :regexp, irange: :range, erange: :range
          }.freeze
          # rubocop:enable Lint/BooleanSymbol

          METHOD_RETURN_TYPES = {
            string: {
              upcase: :string, downcase: :string, capitalize: :string,
              swapcase: :string, strip: :string, lstrip: :string, rstrip: :string,
              chomp: :string, chop: :string, reverse: :string,
              sub: :string, gsub: :string, tr: :string, tr_s: :string,
              squeeze: :string, delete: :string, delete_prefix: :string,
              delete_suffix: :string, slice: :string, succ: :string, next: :string,
              center: :string, ljust: :string, rjust: :string,
              inspect: :string, dump: :string, encode: :string, force_encoding: :string,
              to_s: :string, freeze: :string, dup: :string, clone: :string,
              :+ => :string, :* => :string,
              :[] => :string,
              to_sym: :symbol, intern: :symbol,
              to_i: :integer, hex: :integer, oct: :integer, ord: :integer,
              to_f: :float,
              split: :array, chars: :array, bytes: :array, lines: :array,
              scan: :array, unpack: :array, codepoints: :array, grapheme_clusters: :array,
              each_char: :enumerator, each_byte: :enumerator, each_line: :enumerator,
              size: :integer, length: :integer, bytesize: :integer, count: :integer,
              start_with?: :boolean, end_with?: :boolean, include?: :boolean,
              empty?: :boolean, match?: :boolean, ascii_only?: :boolean,
              valid_encoding?: :boolean, frozen?: :boolean,
              :== => :boolean, :=== => :boolean, :!= => :boolean,
              :< => :boolean, :> => :boolean, :<= => :boolean, :>= => :boolean,
              :<=> => :integer, casecmp: :integer, casecmp?: :boolean,
              hash: :integer
            }.freeze,
            symbol: {
              to_s: :string, id2name: :string, inspect: :string,
              upcase: :symbol, downcase: :symbol, capitalize: :symbol,
              swapcase: :symbol, succ: :symbol, next: :symbol,
              to_proc: :proc, to_sym: :symbol,
              length: :integer, size: :integer,
              empty?: :boolean, match?: :boolean,
              :== => :boolean, :=== => :boolean, :<=> => :integer,
              :[] => :string
            }.freeze,
            integer: {
              to_s: :string, inspect: :string, chr: :string,
              to_i: :integer, to_int: :integer, abs: :integer, succ: :integer, pred: :integer,
              magnitude: :integer, bit_length: :integer, digits: :array,
              to_f: :float, fdiv: :float,
              zero?: :boolean, positive?: :boolean, negative?: :boolean,
              even?: :boolean, odd?: :boolean, integer?: :boolean,
              :+ => :integer, :- => :integer, :* => :integer, :/ => :integer,
              :% => :integer, :** => :integer, :<=> => :integer,
              :== => :boolean, :=== => :boolean,
              :< => :boolean, :> => :boolean, :<= => :boolean, :>= => :boolean,
              divmod: :array, coerce: :array,
              times: :enumerator, upto: :enumerator, downto: :enumerator
            }.freeze,
            float: {
              to_s: :string, inspect: :string,
              to_i: :integer, to_int: :integer, truncate: :integer,
              ceil: :integer, floor: :integer, round: :integer,
              to_f: :float, abs: :float, magnitude: :float,
              zero?: :boolean, positive?: :boolean, negative?: :boolean,
              nan?: :boolean, infinite?: :boolean, finite?: :boolean,
              :+ => :float, :- => :float, :* => :float, :/ => :float,
              :== => :boolean, :<=> => :integer
            }.freeze,
            array: {
              first: :unknown, last: :unknown, sample: :unknown, min: :unknown, max: :unknown,
              sum: :unknown, fetch: :unknown, dig: :unknown,
              :[] => :unknown, at: :unknown,
              map: :array, collect: :array, select: :array, filter: :array,
              reject: :array, sort: :array, sort_by: :array, reverse: :array,
              compact: :array, flatten: :array, uniq: :array, take: :array,
              drop: :array, take_while: :array, drop_while: :array,
              each_slice: :enumerator, each_cons: :enumerator,
              zip: :array, product: :array, combination: :enumerator, permutation: :enumerator,
              partition: :array, group_by: :hash, tally: :hash, to_h: :hash,
              chunk_while: :enumerator, slice_when: :enumerator,
              min_by: :unknown, max_by: :unknown, find: :unknown, detect: :unknown,
              join: :string, inspect: :string, to_s: :string, pack: :string,
              size: :integer, length: :integer, count: :integer,
              empty?: :boolean, any?: :boolean, all?: :boolean, none?: :boolean,
              one?: :boolean, include?: :boolean, member?: :boolean, frozen?: :boolean,
              :== => :boolean, :<=> => :integer,
              :+ => :array, :- => :array,
              :& => :array, :| => :array,
              to_a: :array, to_ary: :array, dup: :array, clone: :array, freeze: :array,
              each: :enumerator, each_with_index: :enumerator
            }.freeze,
            hash: {
              keys: :array, values: :array, to_a: :array, entries: :array,
              map: :array, collect: :array, flat_map: :array, sort: :array, sort_by: :array,
              select: :hash, filter: :hash, reject: :hash, compact: :hash,
              merge: :hash, merge!: :hash, transform_keys: :hash, transform_values: :hash,
              invert: :hash, to_h: :hash, slice: :hash, except: :hash, dup: :hash, clone: :hash,
              fetch: :unknown, dig: :unknown, :[] => :unknown, store: :unknown, assoc: :unknown,
              min_by: :unknown, max_by: :unknown, find: :unknown,
              size: :integer, length: :integer, count: :integer,
              empty?: :boolean, any?: :boolean, all?: :boolean,
              include?: :boolean, member?: :boolean,
              key?: :boolean, has_key?: :boolean, value?: :boolean, has_value?: :boolean,
              frozen?: :boolean,
              :== => :boolean,
              inspect: :string, to_s: :string,
              each: :enumerator, each_pair: :enumerator, each_key: :enumerator,
              each_value: :enumerator, each_with_index: :enumerator,
              keys_at: :array, values_at: :array
            }.freeze,
            boolean: {
              :& => :boolean, :| => :boolean, :^ => :boolean, :! => :boolean,
              inspect: :string, to_s: :string,
              :== => :boolean, :=== => :boolean
            }.freeze,
            regexp: {
              match?: :boolean, source: :string, options: :integer,
              casefold?: :boolean, named_captures: :hash, names: :array,
              inspect: :string, to_s: :string
            }.freeze,
            range: {
              first: :unknown, last: :unknown, min: :unknown, max: :unknown,
              begin: :unknown, end: :unknown,
              size: :integer, count: :integer,
              include?: :boolean, cover?: :boolean, exclude_end?: :boolean,
              to_a: :array, to_ary: :array, entries: :array,
              map: :array, select: :array, reject: :array,
              each: :enumerator, step: :enumerator,
              inspect: :string, to_s: :string
            }.freeze,
            nil_value: {
              to_s: :string, inspect: :string, to_a: :array, to_h: :hash,
              to_i: :integer, to_f: :float,
              nil?: :boolean, :& => :boolean, :| => :boolean, :^ => :boolean,
              :== => :boolean
            }.freeze,
            enumerator: {
              to_a: :array, to_h: :hash, first: :unknown, next: :unknown, peek: :unknown,
              map: :array, select: :array, reject: :array, sort: :array,
              count: :integer, size: :integer,
              with_index: :enumerator, with_object: :enumerator,
              include?: :boolean, any?: :boolean, all?: :boolean
            }.freeze,
            proc: {
              call: :unknown, :[] => :unknown,
              arity: :integer, lambda?: :boolean, curry: :proc, to_proc: :proc
            }.freeze,
            set: {
              add: :set, add?: :set, delete: :set, delete?: :set,
              merge: :set, replace: :set, clear: :set,
              union: :set, intersection: :set, difference: :set,
              subtract: :set, flatten: :set, classify: :hash, divide: :set,
              keep_if: :set, delete_if: :set, reject!: :set, select!: :set, filter!: :set,
              :+ => :set, :- => :set, :& => :set, :| => :set, :^ => :set,
              dup: :set, clone: :set, freeze: :set,
              size: :integer, length: :integer, count: :integer, hash: :integer,
              empty?: :boolean, include?: :boolean, member?: :boolean,
              subset?: :boolean, superset?: :boolean, disjoint?: :boolean,
              proper_subset?: :boolean, proper_superset?: :boolean,
              intersect?: :boolean, frozen?: :boolean,
              any?: :boolean, all?: :boolean, none?: :boolean, one?: :boolean,
              :== => :boolean, :=== => :boolean,
              to_a: :array, to_ary: :array, sort: :array,
              map: :array, collect: :array, select: :array, filter: :array,
              reject: :array, partition: :array, group_by: :hash,
              min: :unknown, max: :unknown, min_by: :unknown, max_by: :unknown,
              first: :unknown, find: :unknown, detect: :unknown,
              to_set: :set, sort_by: :array, tally: :hash,
              each: :enumerator, each_with_index: :enumerator, each_with_object: :enumerator,
              inspect: :string, to_s: :string, join: :string
            }.freeze
          }.freeze

          REVERSE_LOOKUP = METHOD_RETURN_TYPES.each_with_object({}) do |(_, methods), table|
            methods.each do |method, return_type|
              table[method] = table.key?(method) && table[method] != return_type ? :unknown : return_type
            end
          end.freeze

          def self.next_type(type, method)
            METHOD_RETURN_TYPES.dig(type, method)
          end

          def self.reverse_lookup(method)
            REVERSE_LOOKUP[method]
          end

          def self.literal_type(node)
            LITERAL_MAP[node.type]
          end

          def self.pass_through?(method)
            PASS_THROUGH.include?(method)
          end

          def self.operator?(method)
            OPERATOR_METHODS.include?(method)
          end
        end
      end
    end
  end
end
