using ClosedXML.Excel;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Infrastructure.Reports;

/// <summary>
/// Renders the registration cards to a flattened .xlsx sheet — one row per student,
/// with every flat field plus the nested mother/father/guardian/fees fields as columns.
/// </summary>
public sealed class RegistrationCardExcelRenderer
{
    // Header text + selector, in display order. Text fields are written as text so
    // codes/DNIs keep leading zeros; fee columns are written as numbers.
    private static readonly (string Header, Func<RegistrationCardDTO, object?> Value, bool Numeric)[] Columns =
    {
        ("Código", s => s.enrollmentCode, false),
        ("Fecha Matrícula", s => s.enrollmentDate, false),
        ("Año", s => s.schoolYear, false),
        ("Nivel", s => s.level, false),
        ("Grado", s => s.grade, false),
        ("Sección", s => s.section, false),
        ("Turno", s => s.shift, false),
        ("Apellido Paterno", s => s.paternalLastName, false),
        ("Apellido Materno", s => s.maternalLastName, false),
        ("Nombres", s => s.firstName, false),
        ("Fecha Nac.", s => s.birthDate, false),
        ("Lugar Nac.", s => s.birthPlace, false),
        ("País", s => s.birthCountry, false),
        ("Sexo", s => s.gender, false),
        ("Religión", s => s.religion, false),
        ("DNI", s => s.dni, false),
        ("N° Hermanos", s => s.siblings, true),
        ("Lugar que ocupa", s => s.siblingPosition, true),
        ("Discapacidad", s => s.disability, false),
        ("Colegio Procedencia", s => s.previousSchool, false),
        ("Dirección", s => s.address, false),
        ("Distrito", s => s.district, false),

        ("Madre Apellido Paterno", s => s.mother?.paternalLastName, false),
        ("Madre Apellido Materno", s => s.mother?.maternalLastName, false),
        ("Madre Nombres", s => s.mother?.firstName, false),
        ("Madre DNI", s => s.mother?.dni, false),
        ("Madre Celular", s => s.mother?.phone, false),
        ("Madre Email", s => s.mother?.email, false),
        ("Madre Grado Instr.", s => s.mother?.educationLevel, false),
        ("Madre Ocupación", s => s.mother?.occupation, false),
        ("Madre Estado Civil", s => s.mother?.maritalStatus, false),

        ("Padre Apellido Paterno", s => s.father?.paternalLastName, false),
        ("Padre Apellido Materno", s => s.father?.maternalLastName, false),
        ("Padre Nombres", s => s.father?.firstName, false),
        ("Padre DNI", s => s.father?.dni, false),
        ("Padre Celular", s => s.father?.phone, false),
        ("Padre Email", s => s.father?.email, false),
        ("Padre Grado Instr.", s => s.father?.educationLevel, false),
        ("Padre Ocupación", s => s.father?.occupation, false),
        ("Padre Estado Civil", s => s.father?.maritalStatus, false),

        ("Apoderado Parentesco", s => s.guardian?.relationship, false),
        ("Apoderado Apellido Paterno", s => s.guardian?.paternalLastName, false),
        ("Apoderado Apellido Materno", s => s.guardian?.maternalLastName, false),
        ("Apoderado Nombres", s => s.guardian?.firstName, false),
        ("Apoderado DNI", s => s.guardian?.dni, false),
        ("Apoderado Celular", s => s.guardian?.phone, false),
        ("Apoderado Email", s => s.guardian?.email, false),

        ("Inscripción Monto", s => s.fees.registrationFee, true),
        ("Inscripción Descuento", s => s.fees.registrationDiscount, true),
        ("Matrícula Monto", s => s.fees.enrollmentFee, true),
        ("Matrícula Descuento", s => s.fees.enrollmentDiscount, true),
        ("Pensión Monto", s => s.fees.tuition, true),
        ("Pensión Descuento", s => s.fees.tuitionDiscount, true),
    };

    public byte[] Render(IReadOnlyList<RegistrationCardDTO> students)
    {
        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add("Ficha Matrícula");

        for (var c = 0; c < Columns.Length; c++)
        {
            var cell = ws.Cell(1, c + 1);
            cell.Value = Columns[c].Header;
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromArgb(0x1A, 0x1A, 0x2E);
            cell.Style.Font.FontColor = XLColor.White;
        }

        for (var r = 0; r < students.Count; r++)
        {
            for (var c = 0; c < Columns.Length; c++)
            {
                var cell = ws.Cell(r + 2, c + 1);
                var value = Columns[c].Value(students[r]);

                if (Columns[c].Numeric)
                {
                    cell.Value = value switch
                    {
                        decimal d => d,
                        int i => i,
                        _ => 0
                    };
                }
                else
                {
                    cell.Style.NumberFormat.Format = "@";
                    cell.Value = value?.ToString() ?? string.Empty;
                }
            }
        }

        ws.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }
}
