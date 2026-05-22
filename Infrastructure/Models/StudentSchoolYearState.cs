using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class StudentSchoolYearState
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Description { get; set; } = null!;
}
