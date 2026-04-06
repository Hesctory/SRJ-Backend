using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SecondLanguage
{
    public int EducationalPersonId { get; set; }

    public string? SecondLanguage1 { get; set; }

    public virtual EducationalPerson EducationalPerson { get; set; } = null!;
}
