"""
mkdocs-macros-plugin python file
"""
def define_env(env):
    """
    This is the hook for the variables, macros and filters.
    """
    WEBROOT="https://github.com/NPACore/fw-mrrcqa/blob/main"

    @env.macro
    def gitlink(fname: str):
        "Calculate price"
        return f'<a href="{WEBROOT}/{fname}"><code>{fname}</code></a>'
