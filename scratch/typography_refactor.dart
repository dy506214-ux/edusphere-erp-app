import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/features.dart';

void main() async {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('typography.dart')) continue;

    try {
      final content = await file.readAsString();
      final result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        path: file.path,
      );

      final visitor = TypographyVisitor(content);
      result.unit.visitChildren(visitor);

      if (visitor.replacements.isNotEmpty) {
        // Apply replacements from back to front to avoid offset shifting
        visitor.replacements.sort((a, b) => b.offset.compareTo(a.offset));
        
        String newContent = content;
        for (final rep in visitor.replacements) {
          newContent = newContent.replaceRange(rep.offset, rep.offset + rep.length, rep.replacement);
        }

        // Ensure AppTypography import is present if we made changes
        if (!newContent.contains('AppTypography')) {
          // Find the last import
          final importRegex = RegExp(r'^import .*;$', multiLine: true);
          final matches = importRegex.allMatches(newContent);
          if (matches.isNotEmpty) {
            final lastMatch = matches.last;
            newContent = newContent.replaceRange(
              lastMatch.end,
              lastMatch.end,
              '\nimport \'package:edusphere/theme/typography.dart\';',
            );
          } else {
             newContent = 'import \'package:edusphere/theme/typography.dart\';\n' + newContent;
          }
        }

        await file.writeAsString(newContent);
        print('Updated: ${file.path}');
      }
    } catch (e) {
      print('Error processing ${file.path}: $e');
    }
  }
}

class Replacement {
  final int offset;
  final int length;
  final String replacement;

  Replacement(this.offset, this.length, this.replacement);
}

class TypographyVisitor extends RecursiveAstVisitor<void> {
  final String source;
  final List<Replacement> replacements = [];

  TypographyVisitor(this.source);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    if (node.constructorName.type.name2.lexeme == 'TextStyle') {
      _processTextStyle(node, node.argumentList);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (node.target?.toSource() == 'GoogleFonts' && node.methodName.name == 'inter') {
      _processTextStyle(node, node.argumentList);
    }
  }

  void _processTextStyle(AstNode node, ArgumentList argumentList) {
    Expression? fontSizeExpr;
    Expression? fontWeightExpr;
    final otherArgs = <String>[];

    for (final arg in argumentList.arguments) {
      if (arg is NamedExpression) {
        if (arg.name.label.name == 'fontSize') {
          fontSizeExpr = arg.expression;
        } else if (arg.name.label.name == 'fontWeight') {
          fontWeightExpr = arg.expression;
        } else {
          otherArgs.add(arg.toSource());
        }
      }
    }

    if (fontSizeExpr != null) {
      double? fontSize = _extractFontSize(fontSizeExpr);
      if (fontSize != null) {
        String token = _mapToToken(fontSize, fontWeightExpr?.toSource());
        
        String replacement;
        if (otherArgs.isEmpty) {
          replacement = token;
        } else {
          replacement = '$token.copyWith(${otherArgs.join(', ')})';
        }

        replacements.add(Replacement(node.offset, node.length, replacement));
      }
    }
  }

  double? _extractFontSize(Expression expr) {
    if (expr is PropertyAccess && expr.propertyName.name == 'sp') {
      final target = expr.target;
      if (target is IntegerLiteral) return target.value?.toDouble();
      if (target is DoubleLiteral) return target.value;
    } else if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    } else if (expr is DoubleLiteral) {
      return expr.value;
    }
    // Handle cases like `14.sp > 0 ? 14.sp : 14.0` or other complex logic by ignoring them or defaulting
    // We will just return null to skip complex expressions
    return null;
  }

  String _mapToToken(double size, String? weightSource) {
    // Basic mapping based on user spec
    // AppTypography tokens: h1 (32), h2 (28), h3 (24), h4 (20), bodyLarge (18), body (16), small (14), caption (12)
    // We try to match size closely.
    
    if (size >= 32) return 'AppTypography.h1';
    if (size >= 28) return 'AppTypography.h2';
    if (size >= 24) return 'AppTypography.h3';
    if (size >= 20) return 'AppTypography.h4';
    if (size >= 18) return 'AppTypography.bodyLarge';
    
    // For 16, it could be body, button, formLabel, navigation, tableHeader
    if (size >= 16) {
      if (weightSource != null && (weightSource.contains('w600') || weightSource.contains('bold') || weightSource.contains('w700'))) {
        return 'AppTypography.tableHeader'; // SemiBold/Bold -> tableHeader or just body with bold, wait
        // The token already includes the weight, so using tableHeader for 16 semibold is fine.
      } else if (weightSource != null && (weightSource.contains('w500') || weightSource.contains('medium'))) {
        return 'AppTypography.button'; // Medium -> button/formLabel/navigation
      }
      return 'AppTypography.body';
    }
    
    if (size >= 14) return 'AppTypography.small';
    if (size >= 12) return 'AppTypography.caption';
    
    // Default fallback
    if (size < 12) return 'AppTypography.caption';
    return 'AppTypography.body';
  }
}
