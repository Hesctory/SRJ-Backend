using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class StudentStatesByYear
{
    public int StudentId { get; set; }

    public int StatusId { get; set; }

    public int SchoolYearId { get; set; }

    public virtual SchoolYear SchoolYear { get; set; } = null!;

    public virtual StudentState Status { get; set; } = null!;

    public virtual Student Student { get; set; } = null!;
}
