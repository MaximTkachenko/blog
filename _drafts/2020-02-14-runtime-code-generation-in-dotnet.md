---
 layout: post 
 title: Runtime code generation in dotnet
 comments: true
---

# Introduction

Code generation is a very interesting topic. Idea to generate methods and classes in runtime sounds like a magic for me. This feature is quite heavily used in guts of DI frameworks, ORMs, different mappers etc. Now I realized that in the past I had some tasks which could be implemented in very efficient way using code generation. Unfortunately during those times I knew nothing about code generation. And when I heard about it first time I couldn't understand where to start. So here I want to demonstrate how to solve particular problem using metaprogramming approach.

# Task description

Let's imagine our application receives data from some source as a `string[]`:
```c#
{"John McClane", "1994-11-05T13:15:30", "4455"}
```
For simlicity only string, integer and datetime values are expected in a source array.
Also I have an attribute:
```c#
[AttributeUsage(AttributeTargets.Property)]
public sealed class ArrayIndexAttribute : Attribute
{
    public ArrayIndexAttribute(int order)
    {
        Order = order;
    }

    public int Order { get; }
}
```
and a class with properties decorated by this attribute to map elements in input array to properties:
```c#
public class Data
{
    [ArrayIndex(0)] public string Name { get; set; } // "John McClane"
    [ArrayIndex(2)] public int Number { get; set; } // "4455"
    [ArrayIndex(1)] public DateTime Birthday { get; set; } // "1994-11-05T13:15:30"
}
```
`Number` property should be set if the second element in source array can be casted to type of the property. At the same time I don't want to limit implementation by `Data` class only. I want to produce the same mapping procedure for any class. For instance, you can take add this code into your application and use it with any class decorated by `ArrayIndexAttribute`. Service interface to produce mapper for arbitary type `T` looks like this:
```c#
public interface IParserFactory
{
    Func<string[], T> GetArrayIndexParser<T>() where T : new();
}
```

# Plain C#

First of all I want to write a plain C# code without code generation and without relection for a known type:
```c#
var data = new Data();
data.Name = Input[0];
if (DateTime.TryParse(Input[1], out var bd))
{
    data.Birthday = bd;
}
if (int.TryParse(Input[2], out var n))
{
    data.Number = n;
}
```
Quite simple, right? 
I want to generate such code for an arbitary type in runtime.

# Reflection

Let's level up and write it using reflection:
```c#
public class ReflectionParserFactory : IParserFactory
{
    public Func<string[], T> GetArrayIndexParser<T>() where T : new()
    {
        return ArrayIndexParse<T>;
    }

    private static T ArrayIndexParse<T>(string[] data) where T : new()
    {
        var instance = new T();
        var props = typeof(T).GetProperties(BindingFlags.Instance | BindingFlags.Public);
        for (int i = 0; i < props.Length; i++)
        {
            var attrs = props[i].GetCustomAttributes(typeof(ArrayIndexAttribute)).ToArray();
            if (attrs.Length == 0)
            {
                continue;
            }

            int order = ((ArrayIndexAttribute)attrs[0]).Order;
            if (order < 0 || order >= data.Length)
            {
                continue;
            }

            if (props[i].PropertyType == typeof(string))
            {
                props[i].SetValue(instance, data[order]);
                continue;
            }

            if (props[i].PropertyType == typeof(int))
            {
                if (int.TryParse(data[order], out var intResult))
                {
                    props[i].SetValue(instance, intResult);
                }

                continue;
            }

            if (props[i].PropertyType == typeof(DateTime))
            {
                if (DateTime.TryParse(data[order], out var dtResult))
                {
                    props[i].SetValue(instance, dtResult);
                }
            }
        }
        return instance;
    }
}
```
It's not actually code generation. Here we wrote generic code to create new instance of class and set properties using reflcetion. But it's slow. If you want to call this code very often it could be an issue. Benchmarks are presented in the last section. I want to implement something more sophisticated.

# Expression trees

- [How to execute expression trees](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/expression-trees/how-to-execute-expression-trees)
- [Expression classes](https://docs.microsoft.com/en-us/dotnet/api/system.linq.expressions?view=netcore-3.1#classes)

```c#
public class ExpressionTreeParserFactory : IParserFactory
{
    public Func<string[], T> GetArrayIndexParser<T>() where T : new()
    {
        var props = typeof(T).GetProperties(BindingFlags.Instance | BindingFlags.Public);

        ParameterExpression inputArray = Expression.Parameter(typeof(string[]), "inputArray");
        ParameterExpression instance = Expression.Variable(typeof(T), "instance");

        var block = new List<Expression>
        {
            Expression.Assign(instance, Expression.New(typeof(T).GetConstructors()[0]))
        };
        var variables = new List<ParameterExpression> {instance};

        foreach (var prop in props)
        {
            var attrs = prop.GetCustomAttributes(typeof(ArrayIndexAttribute)).ToArray();
            if (attrs.Length == 0)
            {
                continue;
            }

            int order = ((ArrayIndexAttribute)attrs[0]).Order;
            if (order < 0)
            {
                continue;
            }

            var orderConst = Expression.Constant(order);
            var orderCheck = Expression.LessThan(orderConst, Expression.ArrayLength(inputArray));

            if (prop.PropertyType == typeof(string))
            {
                var stringPropertySet = Expression.Assign(
                    Expression.Property(instance, prop),
                    Expression.ArrayIndex(inputArray, orderConst));

                block.Add(Expression.IfThen(orderCheck, stringPropertySet));
                continue;
            }

            if (!TypeParsers.Parsers.TryGetValue(prop.PropertyType, out var parser))
            {
                continue;
            }

            var parseResult = Expression.Variable(prop.PropertyType, "parseResult");
            var parserCall = Expression.Call(parser, Expression.ArrayIndex(inputArray, orderConst), parseResult);
            var propertySet = Expression.Assign(
                Expression.Property(instance, prop),
                parseResult);

            var ifSet = Expression.IfThen(parserCall, propertySet);

            block.Add(Expression.IfThen(orderCheck, ifSet));
            variables.Add(parseResult);
        }

        block.Add(instance);

        return Expression.Lambda<Func<string[], T>>(
            Expression.Block(variables.ToArray(), Expression.Block(block)), 
            inputArray).Compile();
    }
}
```

# Emit il

- [How to: Define and Execute Dynamic Methods](https://docs.microsoft.com/en-us/dotnet/framework/reflection-and-codedom/how-to-define-and-execute-dynamic-methods)
- [OpCodes list](https://docs.microsoft.com/en-us/dotnet/api/system.reflection.emit.opcodes?view=netcore-3.1#fields)
- [https://sharplab.io/](https://sharplab.io/)
- [ReSharper IL viewer](https://www.jetbrains.com/help/resharper/Viewing_Intermediate_Language.html)

```c#
public class EmitIlParserFactory : IParserFactory
{
    public Func<string[], T> GetArrayIndexParser<T>() where T : new()
    {
        var props = typeof(T).GetProperties(BindingFlags.Instance | BindingFlags.Public);

        var dm = new DynamicMethod($"from_{typeof(string[]).FullName}_to_{typeof(T).FullName}", 
            typeof(T), new [] { typeof(string[]) }, typeof(EmitIlParserFactory).Module);
        var il = dm.GetILGenerator();

        var instance = il.DeclareLocal(typeof(T));
        il.Emit(OpCodes.Newobj, typeof(T).GetConstructors()[0]);
        il.Emit(OpCodes.Stloc, instance);

        foreach (var prop in props)
        {
            var attrs = prop.GetCustomAttributes(typeof(ArrayIndexAttribute)).ToArray();
            if (attrs.Length == 0)
            {
                continue;
            }

            int order = ((ArrayIndexAttribute)attrs[0]).Order;
            if (order < 0)
            {
                continue;
            }

            var label = il.DefineLabel();

            if (prop.PropertyType == typeof(string))
            {
                il.Emit(OpCodes.Ldc_I4, order);
                il.Emit(OpCodes.Ldarg_0);
                il.Emit(OpCodes.Ldlen);
                il.Emit(OpCodes.Bge_S, label);

                il.Emit(OpCodes.Ldloc, instance);
                il.Emit(OpCodes.Ldarg_0);
                il.Emit(OpCodes.Ldc_I4, order); //question: why not variable through ldloc
                il.Emit(OpCodes.Ldelem_Ref);
                il.Emit(OpCodes.Callvirt, prop.GetSetMethod());

                il.MarkLabel(label);
                continue;
            }

            if (!TypeParsers.Parsers.TryGetValue(prop.PropertyType, out var parser))
            {
                continue;
            }

            il.Emit(OpCodes.Ldc_I4, order);
            il.Emit(OpCodes.Ldarg_0);
            il.Emit(OpCodes.Ldlen);
            il.Emit(OpCodes.Bge_S, label);

            var parseResult = il.DeclareLocal(prop.PropertyType);

            il.Emit(OpCodes.Ldarg_0);
            il.Emit(OpCodes.Ldc_I4, order);
            il.Emit(OpCodes.Ldelem_Ref);
            il.Emit(OpCodes.Ldloca, parseResult);
            il.EmitCall(OpCodes.Call, parser, null);
            il.Emit(OpCodes.Brfalse_S, label);

            il.Emit(OpCodes.Ldloc, instance);
            il.Emit(OpCodes.Ldloc, parseResult);
            il.Emit(OpCodes.Callvirt, prop.GetSetMethod());

            il.MarkLabel(label);
        }

        il.Emit(OpCodes.Ldloc, instance);
        il.Emit(OpCodes.Ret);

        return (Func<string[], T>)dm.CreateDelegate(typeof(Func<string[], T>));
    }
}
```

# Sigil

- [A fail-fast validating helper for .NET CIL generation](https://github.com/kevin-montrose/Sigil)

```c#
public class SigilParserFactory : IParserFactory
{
    public Func<string[], T> GetArrayIndexParser<T>() where T : new()
    {
        var props = typeof(T).GetProperties(BindingFlags.Instance | BindingFlags.Public);

        var il = Emit<Func<string[], T>>.NewDynamicMethod($"from_{typeof(string[]).FullName}_to_{typeof(T).FullName}");

        var instance = il.DeclareLocal<T>();
        il.NewObject<T>();
        il.StoreLocal(instance);

        foreach (var prop in props)
        {
            var attrs = prop.GetCustomAttributes(typeof(ArrayIndexAttribute)).ToArray();
            if (attrs.Length == 0)
            {
                continue;
            }

            int order = ((ArrayIndexAttribute)attrs[0]).Order;
            if (order < 0)
            {
                continue;
            }

            var label = il.DefineLabel();

            if (prop.PropertyType == typeof(string))
            {
                il.LoadConstant(order);
                il.LoadArgument(0);
                il.LoadLength<string>();
                il.BranchIfGreaterOrEqual(label);

                il.LoadLocal(instance);
                il.LoadArgument(0);
                il.LoadConstant(order);
                il.LoadElement<string>();
                il.CallVirtual(prop.GetSetMethod());

                il.MarkLabel(label);
                continue;
            }

            if (!TypeParsers.Parsers.TryGetValue(prop.PropertyType, out var parser))
            {
                continue;
            }

            il.LoadConstant(order);
            il.LoadArgument(0);
            il.LoadLength<string>();
            il.BranchIfGreaterOrEqual(label);

            var parseResult = il.DeclareLocal(prop.PropertyType);
            
            il.LoadArgument(0);
            il.LoadConstant(order);
            il.LoadElement<string>();
            il.LoadLocalAddress(parseResult);
            il.Call(parser);
            il.BranchIfFalse(label);

            il.LoadLocal(instance);
            il.LoadLocal(parseResult);
            il.CallVirtual(prop.GetSetMethod());

            il.MarkLabel(label);
        }

        il.LoadLocal(instance);
        il.Return();

        return il.CreateDelegate();
    }
}
```

# Benchmarks

The post won't be completed without benchamrks. Here I want to compare two things:
- warm up: parser generation step;
- call already generated parser.
Benchmarks are measured using [BenchmarkDotNet](https://github.com/dotnet/BenchmarkDotNet).

# Source code

Here is [github repository](https://github.com/MaximTkachenko/dotnet-runtime-code-generation-samples) with parser factories and unit tests.
