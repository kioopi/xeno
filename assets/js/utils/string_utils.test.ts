import { describe, it, expect } from 'vitest';
import { capitalize, toKebabCase, isValidUUID } from './string_utils';

describe('String Utils', () => {
  describe('capitalize', () => {
    it('capitalizes the first letter of a string', () => {
      expect(capitalize('hello')).toBe('Hello');
      expect(capitalize('world')).toBe('World');
    });

    it('handles already capitalized strings', () => {
      expect(capitalize('Hello')).toBe('Hello');
    });

    it('handles empty strings', () => {
      expect(capitalize('')).toBe('');
    });

    it('handles single character strings', () => {
      expect(capitalize('a')).toBe('A');
    });
  });

  describe('toKebabCase', () => {
    it('converts camelCase to kebab-case', () => {
      expect(toKebabCase('camelCase')).toBe('camel-case');
      expect(toKebabCase('myVariableName')).toBe('my-variable-name');
    });

    it('converts spaces to hyphens', () => {
      expect(toKebabCase('hello world')).toBe('hello-world');
    });

    it('converts underscores to hyphens', () => {
      expect(toKebabCase('hello_world')).toBe('hello-world');
    });

    it('handles already kebab-cased strings', () => {
      expect(toKebabCase('already-kebab')).toBe('already-kebab');
    });
  });

  describe('isValidUUID', () => {
    it('validates correct UUID v4 format', () => {
      expect(isValidUUID('550e8400-e29b-41d4-a716-446655440000')).toBe(true);
      expect(isValidUUID('123e4567-e89b-42d3-a456-426614174000')).toBe(true);
    });

    it('rejects invalid UUID formats', () => {
      expect(isValidUUID('not-a-uuid')).toBe(false);
      expect(isValidUUID('550e8400-e29b-41d4-a716')).toBe(false);
      expect(isValidUUID('')).toBe(false);
    });

    it('rejects UUIDs with wrong version', () => {
      expect(isValidUUID('550e8400-e29b-31d4-a716-446655440000')).toBe(false);
    });

    it('handles case insensitivity', () => {
      expect(isValidUUID('550E8400-E29B-41D4-A716-446655440000')).toBe(true);
    });
  });
});
