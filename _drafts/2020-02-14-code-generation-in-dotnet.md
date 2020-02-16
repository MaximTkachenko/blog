---
 layout: post 
 title: Code generation in dotnet
 comments: true
---

# Introduction

Code generation is a very interesting topic. Idea to generate methods and classes in runtime sounds like a magic for me. This feature is quite heavily used in guts of DI frameworks, ORMs, different mappers etc.

Let's imagine I receive a dictionary from some source in a such format:
```c#
{"Name", "John McClane"},
{"Age", "33"}
```
I want to map this dictionary to any C# type and fill property of C# object if there is a value in the dictionary for property name and value is convertible into property type. Also I don't want to write code for each class I use. Instead I want to be able to map the dictionary to any C# type. So I don't know target C# type while writing my `mapper`.

# Plain C#

First of all I want to write a plain C# code for a known type:
```csharp
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
