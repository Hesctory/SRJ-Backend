using ClosedXML.Excel;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// Renders a <see cref="TableReportModel"/> to an .xlsx workbook: title / subtitle /
/// context rows, then a bold header row and the data. Non-numeric columns are written
/// as text so enrollment codes and DNIs keep any leading zeros.
/// </summary>
public sealed class TableExcelRenderer
{
    public byte[] Render(TableReportModel model, string sheetName)
    {
        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add(Sanitize(sheetName));

        var colCount = Math.Max(model.Columns.Count, 1);
        var row = 1;

        // Title band.
        ws.Cell(row, 1).Value = model.Title;
        ws.Cell(row, 1).Style.Font.Bold = true;
        ws.Cell(row, 1).Style.Font.FontSize = 14;
        ws.Range(row, 1, row, colCount).Merge();
        row++;

        if (!string.IsNullOrWhiteSpace(model.ContextLine))
        {
            ws.Cell(row, 1).Value = model.ContextLine;
            ws.Cell(row, 1).Style.Font.FontColor = XLColor.FromArgb(0x55, 0x55, 0x55);
            ws.Range(row, 1, row, colCount).Merge();
            row++;
        }

        ws.Cell(row, 1).Value = $"Total: {model.Total} estudiante(s)";
        ws.Range(row, 1, row, colCount).Merge();
        row += 2; // blank spacer row before the table

        // Header row.
        var headerRow = row;
        for (var c = 0; c < model.Columns.Count; c++)
        {
            var cell = ws.Cell(headerRow, c + 1);
            cell.Value = model.Columns[c].Header;
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromArgb(0x1A, 0x1A, 0x2E);
            cell.Style.Font.FontColor = XLColor.White;
        }
        row++;

        // Data rows.
        foreach (var dataRow in model.Rows)
        {
            for (var c = 0; c < model.Columns.Count; c++)
            {
                var cell = ws.Cell(row, c + 1);
                var text = c < dataRow.Count ? dataRow[c] ?? string.Empty : string.Empty;

                if (model.Columns[c].Numeric && long.TryParse(text, out var number))
                {
                    cell.Value = number;
                }
                else
                {
                    cell.Style.NumberFormat.Format = "@"; // text — preserve leading zeros
                    cell.Value = text;
                }
            }
            row++;
        }

        ws.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    // Excel sheet names cannot exceed 31 chars or contain : \ / ? * [ ].
    private static string Sanitize(string name)
    {
        var cleaned = new string(name.Where(ch => !"\\/?*[]:".Contains(ch)).ToArray());
        return cleaned.Length > 31 ? cleaned[..31] : cleaned;
    }
}
