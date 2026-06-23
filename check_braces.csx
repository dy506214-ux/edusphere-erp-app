using System;
using System.IO;
using System.Text.RegularExpressions;

string text = File.ReadAllText(""lib/screens/dashboards/student_dashboard.dart"");
int depth = 0;
int lineNum = 1;
bool inString = false;
bool escape = false;

for (int i = 0; i < text.Length; i++) {
    char c = text[i];
    if (c == '\n') { lineNum++; continue; }
    if (c == '\\') { escape = !escape; continue; }
    if (c == '\"' || c == '\'') {
        if (!escape) { inString = !inString; }
    }
    escape = false;
    
    if (!inString) {
        if (c == '{') depth++;
        if (c == '}') {
            depth--;
            if (depth == 0) {
                Console.WriteLine($""Depth reached 0 at line {lineNum}"");
            }
        }
    }
}
