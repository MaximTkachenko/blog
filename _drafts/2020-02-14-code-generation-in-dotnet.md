---
 layout: post 
 title: Code generation in dotnet
 comments: true
---

# Introduction

Code generation is a very interesting topic. Idea to generate methods and classes in runtime sounds like a magic for me. This feature is quite heavily used in guts of DI frameworks, ORMs, different mappers etc. Now I realized that in the past I have some tasks which could be implemented in very efficient way using code generation. Unfortunately during those times I knew nothing about code generation. And when I heard about it first time I couldn't understand where to start. So here I want to demonstrate how to solve particular problem using metaprogramming approach.

# Task description

Let's imagine our application receives data from some source as a `string[]`:
```c#
{"John McClane", "4455", "1994-11-05T13:15:30"}
```
Also I have an attribute class:
```c#
public sealed class ArrayIndexAttribute : Attribute
{
    public ArrayIndexAttribute(int order)
    {
        Order = order;
    }

    public int Order { get; }
}
```
and a class:
```c#
public class Data
{
    [ArrayIndex(0)] public string Name { get; set; }
    [ArrayIndex(2)] public int Number { get; set; }
    [ArrayIndex(1)] public DateTime Birthday { get; set; }
}
```
I want to set `Number` property if the second element in source array can be casted to type of the property. At the same time I don't want to limit implementation by `Data` only. I want to produce the same mapping procedure for any class. Service interface to produce mapper for arbitary type `T` looks like this:
```c#
public interface IParserFactory
{
    Func<string[], T> GetArrayIndexParser<T>() where T : new();
}
```

# Plain C#

First of all I want to write a plain C# code for a known type:
```c#

```
Quite simple, right? 

# Reflection

Let's level up. 
```csharp
```

# Emit il

Documentation from Microsoft: [How to: Define and Execute Dynamic Methods](https://docs.microsoft.com/en-us/dotnet/framework/reflection-and-codedom/how-to-define-and-execute-dynamic-methods)

(https://sharplab.io/)[https://sharplab.io/]
(ReSharper IL viewer)[https://www.jetbrains.com/help/resharper/Viewing_Intermediate_Language.html]

```csharp
```

# Expression trees

Documentation from Microsoft: [How to execute expression trees](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/expression-trees/how-to-execute-expression-trees)

```csharp
```

# Sigil

Github: [A fail-fast validating helper for .NET CIL generation](https://github.com/kevin-montrose/Sigil)

```csharp
```

# Unit tests and benchmarks

todo

# Source code, unit test and benchmarks

todo put git here
