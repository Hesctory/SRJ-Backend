using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Grade
{
    public int Id { get; set; }

    public int LevelId { get; set; }

    public string Name { get; set; } = null!;

    public int Year { get; set; }

    public virtual ICollection<GradeOffering> GradeOfferings { get; set; } = new List<GradeOffering>();

    public virtual Level Level { get; set; } = null!;
}
