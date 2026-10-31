import { beforeAll, describe, expect, test } from "vitest";
import { EmptyFileSystem, type LangiumDocument } from "langium";
import { expandToString as s } from "langium/generate";
import { parseHelper } from "langium/test";
import type { Model } from "mercury-language";
import { createMercuryServices, isModel } from "mercury-language";

let services: ReturnType<typeof createMercuryServices>;
let parse:    ReturnType<typeof parseHelper<Model>>;
let document: LangiumDocument<Model> | undefined;

beforeAll(async () => {
    services = createMercuryServices(EmptyFileSystem);
    parse = parseHelper<Model>(services.Mercury);

    // activate the following if your linking test requires elements from a built-in library, for example
    // await services.shared.workspace.WorkspaceManager.initializeWorkspace([]);
});

describe('Parsing tests', () => {

    test('parse simple Model', async () => {
        document = await parse(`
            person Langium
            Hello Langium!
        `);

        // check for absence of parser errors the classic way:
        //  deactivated, find a much more human readable way below!
        // expect(document.parseResult.parserErrors).toHaveLength(0);

        const items = document.parseResult.value?.items?.map(item =>
            'name' in item ? `decl ${item.name}` : `clause ${item.person.$refText}`
        ) ?? [];

        expect(
            // here we use a (tagged) template expression to create a human readable representation
            //  of the AST part we are interested in and that is to be compared to our expectation;
            // prior to the tagged template expression we check for validity of the parsed document object
            //  by means of the reusable function 'checkDocumentValid()' to sort out (critical) typos first;
            checkDocumentValid(document) || `Items:\n  ${items.join('\n  ')}`
        ).toBe(`Items:\n  decl Langium\n  clause Langium`);
    });

    test('parse module declaration with qualified name', async () => {
        document = await parse(`
            :- module check_hlds.abstract_mode_constraints.
        `);

        const decl = document.parseResult.value?.items?.[0] as any;
        expect(checkDocumentValid(document) || decl?.$type).toBe('Decl');
        expect(checkDocumentValid(document) || decl?.body?.name).toBe('check_hlds');
        expect(checkDocumentValid(document) || decl?.body?.names?.join('.')).toBe('abstract_mode_constraints');
    });

    test('parse pred declaration with determinism annotation', async () => {
        document = await parse(`
            :- pred test_if_builtin(module_name::in, string::in, int::in) is semidet.
        `);

        expect(checkDocumentValid(document)).toBeUndefined();
        const decl = document.parseResult.value?.items?.[0] as any;
        expect(decl?.$type).toBe('Decl');
        expect(decl?.body?.$type).toBe('pred');
        expect(decl?.body?.name).toBe('test_if_builtin');
    });

    test('parse pred declaration with parameterized type modes', async () => {
        document = await parse(`
            :- pred translate_builtin(module_name::in, string::in, proc_id::in,
                list(T)::in, simple_code(T)::out) is det.
        `);

        expect(checkDocumentValid(document)).toBeUndefined();
        const decl = document.parseResult.value?.items?.[0] as any;
        expect(decl?.$type).toBe('Decl');
        expect(decl?.body?.$type).toBe('pred');
        expect(decl?.body?.name).toBe('translate_builtin');
    });

    test('parse pragma inline with pred arity', async () => {
        document = await parse(`
            :- pragma inline(pred(builtin_translation/5)).
        `);

        expect(checkDocumentValid(document)).toBeUndefined();
        const decl = document.parseResult.value?.items?.[0] as any;
        expect(decl?.$type).toBe('Decl');
        expect(decl?.body?.$type).toBe('Pragma');
        expect(decl?.body?.name).toBe('inline');
    });

    test('parse parenthesized if-then-else goal in body', async () => {
        document = await parse(`
            translate_builtin(FullyQualifiedModule, PredName, ProcId, Args, Code) :-
                ( if
                    is_std_lib_module_name(FullyQualifiedModule, ModuleName),
                    proc_id_to_int(ProcId, ProcNum),
                    builtin_translation(ModuleName, PredName, ProcNum, Args, CodePrime)
                then
                    Code = CodePrime
                else
                    list.length(Args, Arity),
                    string.format("unknown builtin %s/%d", [s(PredName), i(Arity)], Msg),
                    unexpected($pred, Msg)
                ).
        `);

        expect(checkDocumentValid(document)).toBeUndefined();
        const clause = document.parseResult.value?.items?.[0] as any;
        expect(clause?.$type).toBe('Clause');
        expect(clause?.body?.goal?.$type).toBe('IfThenElse');
    });

});

function checkDocumentValid(document: LangiumDocument): string | undefined {
    return document.parseResult.parserErrors.length && s`
        Parser errors:
          ${document.parseResult.parserErrors.map(e => e.message).join('\n  ')}
    `
        || document.parseResult.value === undefined && `ParseResult is 'undefined'.`
        || !isModel(document.parseResult.value) && `Root AST object is a ${document.parseResult.value.$type}, expected a 'Model'.`
        || undefined;
}
