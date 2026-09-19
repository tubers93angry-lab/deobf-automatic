local AST = {}

function AST.node(kind, props)
    props = props or {}
    props.kind = kind
    return props
end

return AST
