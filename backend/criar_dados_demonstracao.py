"""Atalho legado para a preparação canônica completa da demonstração."""


def main() -> int:
    # Mantém compatibilidade com atalhos antigos usando o seed completo atual.
    from seed_demonstracao import main as seed_main

    return seed_main()


if __name__ == "__main__":
    raise SystemExit(main())
