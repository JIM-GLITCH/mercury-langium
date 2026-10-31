import type { ValidationAcceptor, ValidationChecks } from 'langium';
import type { MercuryAstType, Decl } from './generated/ast.js';
import type { MercuryServices } from './mercury-module.js';

/**
 * Register custom validation checks.
 */
export function registerValidationChecks(services: MercuryServices) {
    const registry = services.validation.ValidationRegistry;
    const validator = services.validation.MercuryValidator;
    const checks: ValidationChecks<MercuryAstType> = {
        Decl: validator.checkDeclStartsWithCapital
    };
    registry.register(checks, validator);
}

/**
 * Implementation of custom validations.
 */
export class MercuryValidator {

    checkDeclStartsWithCapital(decl: Decl, accept: ValidationAcceptor): void {
        if (decl.name) {
            const firstChar = decl.name.substring(0, 1);
            if (firstChar.toUpperCase() !== firstChar) {
                accept('warning', 'Decl name should start with a capital.', { node: decl, property: 'name' });
            }
        }
    }

}
