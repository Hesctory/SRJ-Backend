using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EducationalPerson
{
    public int PersonId { get; set; }

    public int? EthnicSelfIdentificationId { get; set; }

    public string? NativeLanguage { get; set; }

    public virtual EthnicSelfIdentification? EthnicSelfIdentification { get; set; }

    public virtual Person Person { get; set; } = null!;

    public virtual SecondLanguage? SecondLanguage { get; set; }

    public virtual Student? Student { get; set; }
}
