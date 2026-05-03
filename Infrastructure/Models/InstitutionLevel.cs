using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class InstitutionLevel
{
    public int LevelId { get; set; }

    public int InstitutionId { get; set; }

    public bool IsActive { get; set; }

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public virtual Institution Institution { get; set; } = null!;

    public virtual Level Level { get; set; } = null!;
}
