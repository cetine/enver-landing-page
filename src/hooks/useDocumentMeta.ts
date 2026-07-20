import { useEffect } from 'react';

const DEFAULT_TITLE = 'Enver Cetin — AI Leader & Architect | Enterprise AI at Scale';
const DEFAULT_DESCRIPTION =
    'Enver Cetin is a Senior Manager AI based in Munich, Germany. He builds production-ready AI systems, agentic architectures, and enterprise automation for Fortune 500 and German Mittelstand companies.';

export function useDocumentMeta({ title, description }: { title: string; description: string }) {
    useEffect(() => {
        document.title = title;
        const meta = document.querySelector('meta[name="description"]');
        if (meta) meta.setAttribute('content', description);

        return () => {
            document.title = DEFAULT_TITLE;
            const meta = document.querySelector('meta[name="description"]');
            if (meta) meta.setAttribute('content', DEFAULT_DESCRIPTION);
        };
    }, [title, description]);
}
